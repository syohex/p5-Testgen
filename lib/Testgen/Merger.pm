package Testgen::Merger;
use strict;
use warnings;

use Carp ();
use Getopt::Long ();
use File::Path ();
use Cwd ();

use Testgen::Config;
use Testgen::Runner::Compiler;
use Testgen::TestDirectory;
use Testgen::Util;

sub new {
    my ($class, %args) = @_;

    my $output_dir = delete $args{output_dir} || 'merged';

    my $match_str = delete $args{match_regexp} || '^ckr';
    my $match_regexp;
    eval {
        $match_regexp = qr/$match_str/;
    };
    if ($@) {
        Carp::croak("invalid regexp $match_str");
    }

    bless {
        help         => undef,
        config_file  => 'runtest.cnf',
        output_dir   => 'merge',
        match_regexp => $match_regexp,
        output_dir   => Cwd::realpath("./$output_dir"),
        argv         => [],
        %args,
    }, $class;
}

sub parse_options {
    my $self = shift;

    local @ARGV = @_;

    Getopt::Long::GetOptions(
        "c|config=s"     => \$self->{config_file},
        "o|output-dir=s" => \$self->{output_dir},
        "h|help"         => \$self->{help},
    );

    if ($self->{help}) {
        _usage();
    }

    $self->{argv} = [ @ARGV ];
}

sub run {
    my $self = shift;

    my $config = Testgen::Config->new( $self->{config_file} );

    my $merge_dir = $self->{output_dir};
    File::Path::rmtree([$merge_dir], 0, 0) if -d $merge_dir;
    File::Path::mkpath([$merge_dir], 0, 0777);

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
            compiler   => $compiler,
            output_dir => $self->{output_dir},
        );
    }

    # output fileset
    my $fileset = File::Spec->catfile($self->{output_dir}, "FILESET");
    open my $fh, '>', $fileset or Carp::croak("Can't open $fileset: $!");
    for my $merge_info (@merge_infos) {
        my ($file_info, $total_oknum) = @{$merge_info};

        if (ref $file_info eq 'ARRAY') {
            print {$fh} join ' ', @{$file_info};
        } else {
            print {$fh} $file_info;
        }

        print {$fh} " : $total_oknum\n";
    }
}

sub _usage {
    die <<"...";
Usage: $0 [options]

Options:
  -c,--config       Specify config file(Default is './runtest.cnf')
  -o,--output-dir   Specify output directory where generated merged file.
  --compiler        Specify compiled used preprocessing(Default is 'gcc')
  -h,--help         Display help message
...
}

1;

__END__
