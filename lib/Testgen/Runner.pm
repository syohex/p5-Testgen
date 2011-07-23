package Testgen::Runner;
use strict;
use warnings;

use Carp ();
use Getopt::Long ();
use File::Path ();
use File::Temp ();
use Cwd ();

use Testgen::Config;
use Testgen::Runner::Compiler;
use Testgen::Runner::Executer;
use Testgen::TestDirectory;
use Testgen::ForkManager;
use Testgen::Util ();

sub new {
    my ($class, %args) = @_;

    my $config_file = delete $args{config_file} || 'runtest.cnf';
    my $log_dir     = delete $args{log_dir}     || 'LOG';

    my $config   = Testgen::Config->new($config_file);
    my $temp_dir = File::Temp::tempdir( CLEANUP => 1 );

    bless {
        help           => undef,
        match_regexp   => undef,
        test_directies => [],
        start_time     => undef,
        config         => $config,
        log_dir        => $log_dir,
        temp_dir       => Cwd::realpath($temp_dir),
        %args,
    }, $class;
}

sub parse_options {
    my $self = shift;

    local @ARGV = @_;

    Getopt::Long::GetOptions(
        'h|help' => \$self->{help},
    );

    if (defined $self->{help}) {
        $self->_usage();
    }

    $self->{argv} = [ @ARGV ];
}

sub run {
    my $self = shift;

    $self->_init;
    $self->_check_argument();

    my @dirs = $self->_get_match_directories;

    for my $dir (sort @dirs) {
        my $guard = Testgen::Util::Chdir->new($dir);

        my $testdir = Testgen::TestDirectory->new(
            name => $dir,
        );
        $testdir->setup( $self->{temp_dir} );

        push @{$self->{test_directies}}, $testdir;
        $self->_do_test($testdir);
    }

    $self->summarize;
}

sub _init {
    my $self = shift;

    my $config = $self->{config};
    $self->{compiler} = Testgen::Runner::Compiler->new(
        compiler     => $config->get('compiler'),
        c_flags      => $config->get('c_flags'),
        ld_flags     => $config->get('ld_flags'),
        options      => $config->get('options'),
    );

    $self->{executer} = Testgen::Runner::Executer->new(
        timeout  => $config->get('timeout'),
        simlator => $config->get('simulator'),
        expect   => '@OK@',
    );

    $self->{start_time} = time;

    unless (-d $self->{log_dir}) {
        File::Path::mkpath([ $self->{log_dir} ], 0, 0777);
    }

    my $base = _log_name( $self->{start_time} );
    $self->{log} = Testgen::Log->new(
        name => "test" . $base,
        dir  => $self->{log_dir},
    );

    $self->{faillog} = Testgen::Log->new(
        name => "faillist" . $base,
        dir  => $self->{log_dir},
    );
}

sub _log_name {
    my $time = shift;

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time);
    $year += 1900;
    $mon  += 1;

    return "${year}-${mon}-${mday}-${hour}${min}${sec}";
}

sub _do_test {
    my ($self, $testdir) = @_;

    my $parallels = $self->{config}->get('parallels') || 1;
#    my $fm = Testgen::ForkManager->new($parallels);

    my $temp_dir = $testdir->temp_dir;
    for my $test ( $testdir->tests ) {
#        $fm->start and next;
        $self->_compile_and_execute($test);
        $test->dump_result( $temp_dir );
#        $fm->finish;
    }
#    $fm->wait_all_children;

    $testdir->summarize;
}

sub _compile_and_execute {
    my ($self, $test) = @_;

    my $compiler = $self->{compiler};
    my $executer = $self->{executer};

    my ($compile_result, $execute_result);
    for my $option ( @{$compiler->options} ) {
        $compile_result = $compiler->compile($test, $option);
        next if $compile_result->is_error || $self->_compile_only;

        $execute_result = $executer->execute($test);
    } continue {
        $test->analyze_result($compile_result, $execute_result);
        $test->finalize;

        ($compile_result, $execute_result) = (undef, undef);
    }
}

sub _get_match_directories {
    my $self = shift;
    my @dirs = grep {
        -d $_ && $_ ne $self->{log_dir}
    } Testgen::Util::read_directory('.');

    return @dirs unless defined $self->{match_regexp};

    my $regexp = $self->{match_regexp};
    return grep m{$regexp}, @dirs;
}

sub _check_argument {
    my $self = shift;

    for my $regexp (@{$self->{argv}}) {
        my $re;
        eval {
            $re = qr/$regexp/;
        };
        if ($@) {
            Carp::croak("Invalid regexp $regexp");
        }

        # original code, last one is enable.
        $self->{match_regexp} = $re;
    }
}

sub _compile_only {
    $_[0]->{conf}->{compile_only};
}

sub summarize {
    my $self = shift;

    $self->_concat_logs;

    my $test_num = 0;
    my ($compile_success, $compile_failure) = (0, 0);
    my ($execute_success, $execute_failure) = (0, 0);

    for my $testdir ( @{$self->{test_directies}} ) {
        my $result_ref = $testdir->result;

        $test_num += $result_ref->{test_num};

        $compile_success += $result_ref->{compile_success};
        $compile_failure += $result_ref->{compile_failure};
        $execute_success += $result_ref->{execute_success};
        $execute_failure += $result_ref->{execute_failure};
    }

    $test_num        = sprintf "%8d", $test_num;
    $compile_success = sprintf "%8d", $compile_success;
    $compile_failure = sprintf "%8d", $compile_failure;
    $execute_success = sprintf "%8d", $execute_success;
    $execute_failure = sprintf "%8d", $execute_failure;

    my $compile_success_rate
        = sprintf "%5.1f", (($compile_success / $test_num) * 100);
    my $compile_failure_rate
        = sprintf "%5.1f", 100 - (($compile_success / $test_num) * 100);

    my $execute_success_rate
        = sprintf "%5.1f", ($execute_success / $test_num) * 100;
    my $execute_failure_rate
        = sprintf "%5.1f", 100 - (($execute_success / $test_num) * 100);

    my $start_time = scalar localtime($self->{start_time});
    my $end_time   = scalar localtime(time);
    my $formatted =<<"...";

------------------------------------------
Total          : $test_num
Passed Compile : $compile_success ($compile_success_rate \%)
Failed Compile : $compile_failure ($compile_failure_rate \%)
Passed Execute : $execute_success ($execute_success_rate \%)
Failed Execute : $execute_failure ($execute_failure_rate \%)

Test Start     : $start_time
Test Finish    : $end_time
------------------------------------------
...

    $self->{log}->print($formatted);
    print $formatted;
}

sub _concat_logs {
    my $self = shift;
    my $guard = Testgen::Util::Chdir->new( $self->{temp_dir} );

    my @entries  = Testgen::Util::read_directory( '.' );
    my @logs     = grep m/\.log$/,  @entries;
    my @faillogs = grep m/\.flog$/, @entries;

    _concatenate_log($self->{log}, \@logs);
    _concatenate_log($self->{faillog}, \@faillogs);
}

sub _concatenate_log {
    my ($log, $files_ref) = @_;

    for my $file ( @{$files_ref} ) {
        my $str = do {
            local $/;
            open my $fh, '<', $file or die "Can't open $file $!";
            <$fh>
        };
        $log->print($str);
    }
}

sub _usage {
    print <<'...';
Usage : runtest.pl [options] [Regexp]

Options:
  -h,--help     display this help message

Examples:

   ./runtest.pl             # test all directories
   ./runtest.pl '^c89-'     # test only c89-* directories

...
    exit 1;
}

1;

__END__
