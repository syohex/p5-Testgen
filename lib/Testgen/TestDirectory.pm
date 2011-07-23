package Testgen::TestDirectory;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw(blessed);
use File::Temp ();
use Term::ANSIColor ();

use Testgen::TestDirectory::Test;
use Testgen::Util ();

our $COLOR = 0;

my $fileset_name = 'FILESET';

sub new {
    my ($class, %args) = @_;

    unless (exists $args{name}) {
        Carp::croak("missing mandatory parameter 'name'");
    }

    bless {
        tests        => [],
        result_cache => undef,
        temp_dir     => File::Temp::tempdir( CLEANUP => 1 ),
        %args,
    }, $class;
}

# accessor
sub temp_dir { shift->{temp_dir} }

sub tests {
    my $self = shift;
    return @{$self->{tests}};
}

sub setup {
    my ($self, $temp_log_dir) = @_;
    $self->_collect_tests;
}

sub result {
    my $self = shift;
    $self->_count_results unless defined $self->{result_cache};

    return $self->{result_cache};
}

sub _collect_tests {
    my $self = shift;

    my @cfiles = _get_cfiles('.');

    if (-e $fileset_name) {
        my %cfile;
        map { $cfile{$_} = 1 } @cfiles;
        my @specified_tests = $self->_read_fileset(\%cfile);

        @cfiles = (keys %cfile, @specified_tests);
    }

    my @tests;
    for my $cfile (@cfiles) {
        my $test;

        if (! blessed $cfile) {
            $test = Testgen::TestDirectory::Test->new(
                dir      => $self->{name},
                files    => $cfile,
            );
        } else {
            $test = $cfile;
        }

        unless (defined $test->oknum) {
            $test->count_ok_num();
        }

        push @tests, $test;
    }

    my @sorted = do {
        # do more efficient
        sort { $a->input cmp $b->input } @tests;
    };

    $self->{tests} = \@sorted;
}

sub _read_fileset {
    my ($self, $cfiles_ref) = @_;

    my $regexp = qr{
         \A ([^:]+)           # $1 = file_list
         \s*
         (?:
             : \s* (\d+) \s*  # $2 = ok_num
         )?
         \z
    }xmso;

    open my $fh, '<', $fileset_name or Carp::croak("Can't open '$fileset_name'");

    my @tests;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m{^\s*$};

        if ($line =~ m{ $regexp }xms) {
            my ($file_list, $oknum) = ($1, $2);

            my @files = split /\s+/, $file_list;
            for my $file (@files) {
                delete $cfiles_ref->{$file};
            }

            push @tests, Testgen::TestDirectory::Test->new(
                files   => [ sort @files ],
                oknum   => $oknum,
                dir     => $self->{name},
            );
        }
    }

    close $fh;

    return @tests;
}

sub _get_cfiles {
    my $dir = shift;
    return grep m{\.c$}x, Testgen::Util::read_directory($dir);
}

sub summarize {
    my ($self, $log, $faillog) = @_;

    my $result = $self->_collect_results($log, $faillog);

    if ($result->{test_num} == 0) {
        Carp::carp("[$self->{name}] You don't any tests!!");
        return;
    }

    my $name;
    if ( $COLOR ) {
        my $status_color;
        if ( $result->{test_num} == $result->{execute_success} ) {
            $status_color = 'green';
        } elsif ( $result->{test_num} == $result->{compile_success} ) {
            $status_color = 'yellow';
        } else {
            $status_color = 'red';
        }

        $name = Term::ANSIColor::color('bold', $status_color)
                . "[$self->{name}]" . Term::ANSIColor::color('reset');
    } else {
        $name = "[$self->{name}]";
    }

    my $compile_ok = join '/', $result->{compile_success}, $result->{test_num};
    my $execute_ok = join '/', $result->{execute_success}, $result->{test_num};

    printf "%s Compile OK %s, Execute OK => %s \n",
        $name, $compile_ok, $execute_ok;
}

sub _collect_results {
    my ($self, $log, $faillog) = @_;

    my @params = qw/test_num
                    compile_success compile_failure
                    execute_success execute_failure/;
    my %cache;

    my @entries = Testgen::Util::read_directory( $self->{temp_dir} );
    for my $result_file ( sort @entries ) {
        my $file = File::Spec->catfile($self->{temp_dir}, $result_file);
        my $result_ref = do $file or die "Can't load $file $!";

        $log->print($result_ref->{log});
        if (exists $result_ref->{faillog}) {
            $faillog->print($result_ref->{faillog})
        }

        for my $param ( @params ) {
            $cache{$param} += $result_ref->{$param};
        }
    }
    undef $self->{temp_dir}; # cleanup

    $self->{result_cache} = \%cache;
}

1;

__END__
