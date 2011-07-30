package Testgen::TestDirectory;
use strict;
use warnings;

use Carp ();
use Cwd ();
use Scalar::Util qw(blessed);
use File::Temp ();
use Term::ANSIColor ();

use Testgen::TestDirectory::Test;
use Testgen::Merger::MergedFile;
use Testgen::Util ();

our $COLOR = 0;

my $fileset_name = 'FILESET';

sub new {
    my ($class, %args) = @_;

    unless (exists $args{name}) {
        Carp::croak("missing mandatory parameter 'name'");
    }

    my $temp_dir = File::Temp->newdir( DIR => Cwd::getcwd );

    bless {
        tests        => [],
        result_cache => undef,
        temp_dir     => $temp_dir,
        %args,
    }, $class;
}

# accessor
sub temp_dir { shift->{temp_dir}->dirname }

sub tests {
    my $self = shift;
    return @{$self->{tests}};
}

sub setup {
    my $self = shift;
    $self->_collect_tests;
}

sub result {
    my $self = shift;
    $self->_count_results unless defined $self->{result_cache};

    return $self->{result_cache};
}

sub _collect_tests {
    my $self = shift;

    my @cfiles = grep m{\.c$}x, Testgen::Util::read_directory('.');

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

    my @sorted = sort { $a->input cmp $b->input } @tests;
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

    printf "%s Compile OK => %s, Execute OK => %s \n",
        $name, $compile_ok, $execute_ok;
}

sub _collect_results {
    my ($self, $log, $faillog) = @_;

    my @params = qw/test_num
                    compile_success compile_failure
                    execute_success execute_failure/;
    my %cache;

    my $dir_name = $self->{temp_dir}->dirname;
    my @entries = Testgen::Util::read_directory( $dir_name );
    for my $result_file ( sort @entries ) {
        my $file = File::Spec->catfile($dir_name, $result_file);
        my $result_ref = do $file or die "Can't load $file $!";

        $log->print($_) for @{$result_ref->{log}};
        if (exists $result_ref->{faillog}) {
            $faillog->print($_) for @{$result_ref->{faillog}};
        }

        for my $param ( @params ) {
            $cache{$param} += $result_ref->{$param};
        }
    }

    $self->{result_cache} = \%cache;
}

sub merge_tests {
    my ($self, %args) = @_;

    my $compiler = $args{compiler};
    my $output_dir = $args{output_dir};

    my $main_file = Testgen::Merger::MergedFile->new( compiler => $compiler );
    my $sub_file  = Testgen::Merger::MergedFile->new( compiler => $compiler );

    my ($total_oknum, $has_subfile) = (0, 0);
    my %cache;
    for my $test ( @{$self->{tests}} ) {
        $total_oknum += $test->oknum();

        my (@mains, @subs);
        for my $file ( $test->files ) {
            if (exists $cache{$file} || _has_main($file) ) {
                push @mains, $file;
                $cache{$file} = 1;
            } else {
                push @subs, $file;
                $has_subfile = 1;
            }
        }

        # maybe fails to link
        Carp::carp("Multiple main files") if scalar @mains >= 2;

        my $prefix = $test->merged_prefix;
        $main_file->add($_, $prefix) for @mains;
        $sub_file->add($_, $prefix) for @subs;
    }

    my ($main_name, $sub_name) = ($self->{name} . ".c", $self->{name} . "-sub.c");

    my $main = File::Spec->catfile($output_dir, $main_name);
    my $sub  = File::Spec->catfile($output_dir, $sub_name);

    $main_file->output_as_main_file($main);

    if ($has_subfile) {
        # for multi file compilation
        $sub_file->output_as_sub_file($sub);
        return [ [$main_name, $sub_name], $total_oknum ];
    }

    return [$main_name, $total_oknum];
}

sub _has_main {
    my $file = shift;
    my $str = do {
        local $/;
        open my $fh, '<', $file or Carp::croak("Can't open $file: $!");
        <$fh>
    };

    my $main_regexp = qr{ \s+ main \s* \( [^)]* \)}xms;
    $str =~ m{$main_regexp};
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::TestDirectory - A test directory class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::TemplateFile->new(%args) :Testgen::TemplateFile >>

Creates and returns a new Testgen::TemplateFile object with I<args>.
Dies on error.

I<%args> might be:

=over

=item name :Str

=back

=head2 Class Variable

=head3 C<< $Testgen::TestDirectory::COLOR :Bool >>

If this variable is true, Output of summary of test directory is colored.
Default is false.

=head2 Instance Methods

=head3 C<< $template_dir->setup() >>

Set up test, collect tests in this directory.

=head3 C<< $template_dir->result() :HashRef >>

Return results of tests in this directory as Hash reference.

=head3 C<< $template_dir->summarize($log, $faillog) >>

Summary of this test directory. Infomation of fail tests are outputed to
C<$faillog>, others are outputed to C<$log>.

=cut
