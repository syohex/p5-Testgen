package Testgen::Merger;
use strict;
use warnings;

use Carp ();
use Getopt::Long ();
use File::Spec ();
use File::Path ();
use File::Basename ();
use Cwd ();

use Testgen::Config;
use Testgen::Runner::Compiler;
use Testgen::TestDirectory;
use Testgen::Util;

sub new {
    my ($class, %args) = @_;

    my $output_dir = delete $args{output_dir} || 'merged';
    my $merged_dir = File::Spec->catfile(Cwd::getcwd(), $output_dir);

    bless {
        help         => undef,
        config_file  => 'runtest.cnf',
        match_regexp => qr/^ckr/,
        output_dir   => $merged_dir,
        %args,
    }, $class;
}

sub parse_options {
    my $self = shift;

    local @ARGV = @_;

    Getopt::Long::GetOptions(
        "c|config=s"     => \$self->{config_file},
        "o|output-dir=s" => \my $output_dir,
        "h|help"         => \$self->{help},
    );

    if ($self->{help}) {
        _usage();
    }

    if ( scalar @ARGV >= 1 ) {
        my $regexp;
        my $arg = shift @ARGV;
        eval {
            $regexp = qr/$arg/;
        };
        if ($@) {
            Carp::croak("invalid regexp argument: '$arg'");
        }

        $self->{match_regexp} = $regexp;
    }

    if (defined $output_dir) {
        my $merged_dir = File::Spec->catfile(Cwd::getcwd(), $output_dir);
        $self->{output_dir} = $merged_dir;
    }
}

sub run {
    my $self = shift;

    my $config = Testgen::Config->new( $self->{config_file} );

    my $merge_dir = $self->{output_dir};
    File::Path::rmtree([$merge_dir], 0, 0) if -d $merge_dir;
    File::Path::mkpath([$merge_dir], 0, oct(777));

    my $regexp = $self->{match_regexp};
    my @target_dirs = grep {
        -d $_ && $_ =~ m{$regexp};
    } Testgen::Util::read_directory('.');

    my $compiler = Testgen::Runner::Compiler->new(
        name      => $config->get('compiler'),
        c_flags   => $config->get('c_flags'),
        ld_flags  => $config->get('ld_flags'),
    );

    my @merge_infos;
    for my $dir (sort @target_dirs) {
        my $guard = Testgen::Util::Chdir->new($dir);

        print "Merge tests in '$dir'\n";

        my $testdir = Testgen::TestDirectory->new( name => $dir );
        $testdir->setup();

        push @merge_infos, $testdir->merge_tests(
            lang       => $config->get('lang'),
            compiler   => $compiler,
            output_dir => $self->{output_dir},
        );
    }

    # output fileset
    my $fileset = File::Spec->catfile($self->{output_dir}, "FILESET");
    open my $fh, '>', $fileset or Carp::croak("Can't open $fileset: $!");
    for my $merge_info (@merge_infos) {
        my ($file_info, $total_oknum) = @{$merge_info};

        my $str = join ' ', map { File::Basename::basename($_) } @{$file_info};
        print {$fh} "$str : $total_oknum\n";
    }
}

sub _usage {
    die <<"...";
Usage: $0 [options]

Options:
  -c,--config       Specify config file(Default is './runtest.cnf')
  -o,--output-dir   Specify output directory where generated merged file.
  -h,--help         Display help message
...
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Merger - Test merger class.

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Merger->new(%args) :Testgen::Merger >>

Creates and returns a new Testgen::Merger object with I<args>.

I<%args> might be:

=over

=item output_dir = 'merged'

=back

=head2 Instance Methods

=head3 C<< $runner->parse_options(@ARGV)  >>

Parse command line options.

=head3 C<< $runner->run() >>

Merge test files and output them into C<$self->{output_dir}>.

=cut
