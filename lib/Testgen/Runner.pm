package Testgen::Runner;
use strict;
use warnings;

use Carp ();
use Cwd ();
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use File::Path ();
use File::Temp ();
use File::Basename ();

use Testgen::Config;
use Testgen::Log;
use Testgen::Runner::Compiler;
use Testgen::Runner::Executor;
use Testgen::TestDirectory;
use Testgen::ForkManager;
use Testgen::Util ();

sub new {
    my ($class, %args) = @_;

    my $config_file = delete $args{config_file} || 'runtest.cnf';
    my $log_dir     = delete $args{log_dir}     || 'LOG';

    my $config   = Testgen::Config->new($config_file);
    my $temp_dir = File::Temp->newdir( DIR => Cwd::getcwd );

    bless {
        help           => undef,
        match_regexp   => undef,
        test_directies => [],
        start_time     => undef,
        config         => $config,
        log_dir        => $log_dir,
        temp_dir       => $temp_dir,
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

        my $testdir = Testgen::TestDirectory->new( name => $dir );
        $testdir->setup();

        push @{$self->{test_directies}}, $testdir;
        $self->_do_test($testdir);
    }

    $self->_summarize;
}

sub _init {
    my $self = shift;

    my $config = $self->{config};
    $self->{compiler} = Testgen::Runner::Compiler->new(
        name     => $config->get('compiler'),
        c_flags  => $config->get('c_flags'),
        ld_flags => $config->get('ld_flags'),
        output_option => $config->get('output_option'),
        option_separator => $config->get('option_separator'),
    );

    $self->{executor} = Testgen::Runner::Executor->new(
        has_print  => $config->get('has_printf'),
        timeout    => $config->get('timeout'),
        simulator  => $config->get('simulator'),
        expect     => $config->get('expect'),
    );

    $self->{start_time} = time;

    unless (-d $self->{log_dir}) {
        File::Path::mkpath([ $self->{log_dir} ], 0, oct(777));
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

    if ($config->get('color')) {
        $Testgen::TestDirectory::COLOR = 1;
    }
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

    my $parallels = $self->{config}->get('parallels');
    if ($^O ne 'MSWin32' && $parallels >= 2) {
        $self->_do_test_parallel($testdir, $parallels);
    } else {
        $self->_do_test_single($testdir);
    }

    $testdir->summarize($self->{log}, $self->{faillog});
}

sub _do_test_single {
    my ($self, $testdir) = @_;

    my $temp_dir = $testdir->temp_dir;
    for my $test ( $testdir->tests ) {
        $self->_compile_and_execute($test);
        $test->dump_result( $temp_dir );
    }
}

sub _do_test_parallel {
    my ($self, $testdir, $parallels) = @_;

    my $fm = Testgen::ForkManager->new($parallels);

    my $temp_dir = $testdir->temp_dir;
    for my $test ( $testdir->tests ) {
        $fm->start and next;
        $self->_compile_and_execute($test);
        $test->dump_result( $temp_dir );
        $fm->finish;
    }
    $fm->wait_all_children;
}

sub _compile_and_execute {
    my ($self, $test) = @_;

    my $compiler = $self->{compiler};
    my $executor = $self->{executor};

    my ($compile_result, $execute_result);
    my @options_list = _option_list($self->{config}->{options});
    for my $option ( @options_list ) {
        $compile_result = $compiler->compile($test, @{$option});
        next if $compile_result->is_error || $self->_is_compile_only;

        $execute_result = $executor->execute($test);
    } continue {
        $test->analyze_result($compile_result, $execute_result);
        $test->finalize;

        ($compile_result, $execute_result) = (undef, undef);
    }
}

sub _option_list {
    my $options_ref = shift;

    my @options_list;
    for my $option ( @{$options_ref} ) {
        if (ref $option eq 'ARRAY') {
            my $combinations = Testgen::Util::combination(
                map { ref $_ eq 'ARRAY' ? $_ : [ $_ ] } @{$option}
            );

            push @options_list, @{$combinations};
        } else {
            push @options_list, [ $option ];
        }
    }

    return scalar @options_list != 0 ? @options_list : ('');
}

sub _get_match_directories {
    my $self = shift;


    my $log_dir  = $self->{log_dir};
    my $temp_dir = File::Basename::basename($self->{temp_dir}->dirname);
    my @dirs = grep {
        -d $_ && ($_ ne $log_dir && $_ ne $temp_dir);
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

sub _is_compile_only {
    $_[0]->{config}->get('compile_only');
}

sub _summarize {
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
    my $guard = Testgen::Util::Chdir->new( $self->{temp_dir}->dirname );

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
    die <<'...';
Usage : runtest.pl [options] [Regexp]

Options:
  -h,--help     display this help message

Examples:

   ./runtest.pl             # test all directories
   ./runtest.pl '^c89-'     # test only c89-* directories

...
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner - Test runner class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner->new(%args) :Testgen::Runner >>

Creates and returns a new Testgen::Runner object with I<args>.

I<%args> might be:

=over

=item config_file :Str = 'runtest.cnf'

Generally 'runtest.cnf' is generated by Testgen::Generator.

=item log_dir :Str = 'LOG'

=back

=head2 Instance Methods

=head3 C<< $runner->parse_options(@ARGV)  >>

Parse command line options.

=head3 C<< $runner->run() >>

Compile and execute tests, and output summary finally.

=cut
