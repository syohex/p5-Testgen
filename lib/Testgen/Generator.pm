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

    my %predefined;
    my $pointer_size = delete $size->{pointer};
    for my $key ( keys %{$size} ) {
        use bignum; ## for very large number
        my $power = $size->{$key};

        my $size_max  = uc('$' . "${key}max");
        my $max_value = sprintf "%s", (2 ** ($power-1)) - 1;

        $max_value .= 'L'  if $key eq 'long';
        $max_value .= 'LL' if $key eq 'long long';

        $predefined{$size_max} = Testgen::TemplateFile::Macro->new(
            name => $size_max, dummy_args => [], body => $max_value,
        );

        my $usize_max  = uc('$' . "u${key}max");
        my $umax_value = sprintf "%s", (2 ** $power) - 1;

        $umax_value .= 'U'   if $key eq 'int';
        $umax_value .= 'UL'  if $key eq 'long';
        $umax_value .= 'ULL' if $key eq 'long long';

        $predefined{$usize_max} = Testgen::TemplateFile::Macro->new(
            name => $usize_max, dummy_args => [], body => $umax_value,
        );

        my $size_min  = uc('$' . "${key}min");
        my $min_value = sprintf "%s", -1 * (2 ** ($power-1));

        $min_value += 1 if $config->get('complement') == 1;

        $min_value .= 'L'  if $key eq 'long';
        $min_value .= 'LL' if $key eq 'long long';

        $predefined{$size_min} = Testgen::TemplateFile::Macro->new(
            name => $size_min, dummy_args => [], body => $min_value,
        );

        if ($pointer_size == $size->{$key}) {
            my $intptr = '$INTPTR';
            $predefined{$intptr} = Testgen::TemplateFile::Macro->new(
                name => $intptr, dummy_args => [], body => $key,
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

    $self->_generate_run_script();
    $self->_generate_run_config();

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
    my $self = shift;

    my $testsuite_dir = $self->{config}->get('testdir');
    my $run_script = File::Spec->catfile($testsuite_dir, 'runtest.pl');

    my $shebang = $Config{perlpath};
    my $libpath = File::Spec->catfile(Cwd::realpath( Cwd::getcwd ), 'lib');

    my $content =<<"...";
#!${shebang}
use strict;
use warnings;

use lib qw(${libpath});
use Testgen::Runner;

my \$runner = Testgen::Runner->new();
\$runner->parse_options(\@ARGV);
\$runner->run();
...

    open my $fh, '>', $run_script or Carp::croak("Can't open $run_script: $!");
    print {$fh} $content;
    close $fh;

    chmod 0755, $run_script or Carp::croak("change permission $run_script $!");
}

sub _generate_run_config {
    my $self = shift;

    my $testsuite_dir = $self->{config}->get('testdir');
    my $run_conf = File::Spec->catfile($testsuite_dir, 'runtest.cnf');

    File::Copy::copy($self->{config_file}, $run_conf)
        or Carp::croak("Can't copy runconfig");

    print "runconfig $run_conf\n";
}

sub _usage {
    die <<"...";
Usage: $0 [options] template_files [...]

Options:
  -c,--config       Specify config file(Default is './tgen.conf')
  -i,--int-only     Test only integer tests(not implemented yet)
  -f,--float-only   Test only float tests(not implemented yet)
  -h,--help         Display help message
...
}

1;

__END__
