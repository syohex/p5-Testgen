package Testgen::Generator;
use strict;
use warnings;

use Carp ();
use Config;
use Cwd ();
use Getopt::Long ();
use File::Spec ();
use File::Path ();
use File::Copy ();

use Testgen::Config;
use Testgen::TemplateFile;
use Testgen::Util ();

sub new {
    my $class = shift;

    bless {
        argv        => [],
        config_file => 'tgen.cnf',
        help        => undef,
        int_only    => undef,    # not implement yet
        float_only  => undef,    # not implement yet
    }, $class;
}

sub parse_options {
    my $self = shift;

    local @ARGV = @_;

    Getopt::Long::GetOptions(
        "c|config=s"   => \$self->{config_file},
        "h|help"       => \$self->{help},
        "i|int-only"   => \$self->{int_only},
        "f|float-only" => \$self->{float_only},
    );

    if ($self->{int_only} && $self->{float_only}) {
        Carp::croak("Cannot enable 'int-only' and 'float-only' option");
    }

    if ($self->{help}) {
        _usage();
    }

    $self->{argv} = [ @ARGV ];
}

sub run {
    my $self = shift;

    $self->_validate();
    $self->{config} = Testgen::Config->new( $self->{config_file} );

    $self->_set_predefined_macros();

    $self->_generate_testsuite();
}

sub _set_predefined_macros {
    my $self = shift;
    my $config = $self->{config};
    my $size = $config->get('size');

    unless (defined $size) {
        return;
    }

    my $pointer_size = delete $size->{pointer};

    my %predefined;
    for my $key ( keys %{$size} ) {
        use bignum; ## for very large number

        $key = 'longlong' if $key eq 'long long';

        my $power = $size->{$key};

        my $size_max  = uc('$' . "${key}max");
        my $max_value = sprintf "%s", (2 ** ($power-1)) - 1;

        $max_value .= 'L'  if $key eq 'long';
        $max_value .= 'LL' if $key eq 'longlong';

        $predefined{$size_max} = Testgen::TemplateFile::Macro->new(
            name => $size_max, body => $max_value,
        );

        my $usize_max  = uc('$' . "u${key}max");
        my $umax_value = sprintf "%s", (2 ** $power) - 1;

        $umax_value .= 'U'   if $key eq 'int';
        $umax_value .= 'UL'  if $key eq 'long';
        $umax_value .= 'ULL' if $key eq 'longlong';

        $predefined{$usize_max} = Testgen::TemplateFile::Macro->new(
            name => $usize_max, body => $umax_value,
        );

        my $size_min  = uc('$' . "${key}min");
        my $min_value = sprintf "%s", -1 * (2 ** ($power-1));

        $min_value += 1 if $config->get('complement') == 1;

        $min_value .= 'L'  if $key eq 'long';
        $min_value .= 'LL' if $key eq 'longlong';

        $predefined{$size_min} = Testgen::TemplateFile::Macro->new(
            name => $size_min, body => $min_value,
        );

        if ($pointer_size == $size->{$key}) {
            my $intptr = '$INTPTR';
            $predefined{$intptr} = Testgen::TemplateFile::Macro->new(
                name => $intptr, body => $key,
            );
        }
    }

    $self->{predefined_macros} = \%predefined;
}

sub _validate {
    my $self = shift;

    if (scalar @{$self->{argv}} == 0) {
        Carp::croak("template files are not specified");
    }

    if ($^O eq 'MSWin32') {
        my @files;

        for my $argv (@{$self->{argv}}) {
            push @files, glob($argv);
        }

        $self->{argv} = \@files;
    }

    for my $template_file (@{$self->{argv}}) {
        unless ($template_file =~ m{\.tt$}) {
            Carp::croak("template file's suffix must be '.tt'");
        }
    }
}

sub _generate_testsuite {
    my $self = shift;
    my $testsuite_dir = $self->{config}->get('testdir');

    _make_dir($testsuite_dir);

    my $perlpath = $Config{perlpath};
    my $libpath = File::Spec->catfile(Cwd::realpath( Cwd::getcwd ), 'lib');

    $self->_generate_run_script(
        output_dir => $testsuite_dir,
        perlpath   => $perlpath,
        libpath    => $libpath,
    );

    $self->_generate_run_config($testsuite_dir);

    $self->_generate_merge_script(
        output_dir => $testsuite_dir,
        perlpath   => $perlpath,
        libpath    => $libpath,
    );

    for my $tt_file (@{$self->{argv}}) {
        my $template = Testgen::TemplateFile->new(
            name           => $tt_file,
            testsuite_dir  => $testsuite_dir,
            macros         => $self->{predefined_macros},
        );

        print "Parse $tt_file\n";
        $template->parse($template);
    }
}

sub _make_dir {
    my $dir = shift;

    if (-f $dir) {
        Carp::croak("Same name file($dir) exists");
    }

    unless (-d $dir) {
        File::Path::mkpath([ $dir ], 0, 0777);
    }
}

sub _generate_run_script {
    my ($self, %args) = @_;

    my $run_script = File::Spec->catfile($args{output_dir}, 'runtest.pl');
    open my $fh, '>', $run_script or Carp::croak("Can't open $run_script: $!");

    print {$fh} <<"...";
#!$args{perlpath}
use strict;
use warnings;

use lib qw($args{libpath});
use Testgen::Runner;

my \$runner = Testgen::Runner->new();
\$runner->parse_options(\@ARGV);
\$runner->run();
...

    close $fh;

    chmod 0755, $run_script or Carp::croak("change permission $run_script $!");

    print "Generate ran script '$run_script'\n";
}

sub _generate_merge_script {
    my ($self, %args) = @_;

    my $merge_script = File::Spec->catfile($args{output_dir}, 'merge.pl');
    open my $fh, '>', $merge_script
        or Carp::croak("Can't open $merge_script: $!");

    print {$fh} <<"...";
#!$args{perlpath}
use strict;
use warnings;

use lib qw($args{libpath});
use Testgen::Merger;

my \$runner = Testgen::Merger->new();
\$runner->parse_options(\@ARGV);
\$runner->run();
...

    close $fh;

    chmod 0755, $merge_script
        or Carp::croak("change permission $merge_script $!");

    print "Generate merge script '$merge_script'\n";
}

sub _generate_run_config {
    my ($self, $output_dir) = @_;

    my $run_conf = File::Spec->catfile($output_dir, 'runtest.cnf');

    File::Copy::copy($self->{config_file}, $run_conf)
        or Carp::croak("Can't copy runconfig");

    print "Generate runconfig '$run_conf'\n";
}

sub _usage {
    die <<"...";
Usage: $0 [options] template_files [...]

Options:
  -c,--config       Specify config file(Default is './tgen.cnf')
  -i,--int-only     Test only integer tests(not implemented yet)
  -f,--float-only   Test only float tests(not implemented yet)
  -h,--help         Display help message
...
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Generator - Test generator class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Generator->new() :Testgen::Generator >>

Creates and returns a new Testgen::Generator object.

=head2 Instance Methods

=head3 C<< $generator->parse_options(@ARGV)  >>

Parse command line options.

=head3 C<< $generator->run() >>

Run test generator.
Read template files, parse them and generate test files.

=cut
