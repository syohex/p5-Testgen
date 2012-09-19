package Testgen::Generator;
use strict;
use warnings;

use Carp ();
use Config;
use Cwd ();
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
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

    my $complement   = $config->get('complement');
    my $pointer_size = delete $size->{pointer};

    my %type_suffix = (
        'long'        => 'L',
        'long long'   => 'LL',
        'float'       => 'F',
        'long double' => 'L',
    );

    my %predefined;
    for my $type ( keys %{$size} ) {
        my $bit_width = $size->{$type};
        # for included space(eg. long long => longlong)
        my $type_name = join '', split /\s/, $type;

        my ($signed_min, $signed_max) = Testgen::Util::get_type_limit(
            type       => $type,
            bit_width  => $bit_width,
            unsigned   => 0,
            complement => $complement,
        );

        if (exists $type_suffix{$type}) {
            $signed_min .= $type_suffix{$type};
            $signed_max .= $type_suffix{$type};
        }

        my $signed_max_limit = uc('$' . "${type_name}max");
        my $signed_min_limit = uc('$' . "${type_name}min");

        $predefined{$signed_max_limit} = Testgen::TemplateFile::Macro->new(
            name => $signed_max_limit, body => $signed_max,
        );

        $predefined{$signed_min_limit} = Testgen::TemplateFile::Macro->new(
            name => $signed_min_limit, body => $signed_min,
        );

        my ($unsigned_min, $unsigned_max) = Testgen::Util::get_type_limit(
            type       => $type,
            bit_width  => $bit_width,
            unsigned   => 1,
            complement => $complement,
        );

        if ($type =~ m{int|long}) {
            $unsigned_min .= "U";
            $unsigned_max .= "U";
        }

        if (exists $type_suffix{$type}) {
            $unsigned_min .= $type_suffix{$type};
            $unsigned_max .= $type_suffix{$type};
        }

        my $unsigned_min_limit = uc('$u' . "${type_name}min");
        my $unsigned_max_limit = uc('$u' . "${type_name}max");

        $predefined{$unsigned_max_limit} = Testgen::TemplateFile::Macro->new(
            name => $unsigned_max_limit, body => $unsigned_max,
        );

        $predefined{$unsigned_min_limit} = Testgen::TemplateFile::Macro->new(
            name => $unsigned_min_limit, body => $unsigned_min,
        );

        if ($pointer_size == $bit_width) {
            my $intptr = '$INTPTR';
            $predefined{$intptr} = Testgen::TemplateFile::Macro->new(
                name => $intptr, body => $type,
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
        File::Path::mkpath([ $dir ], 0, oct(777));
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
