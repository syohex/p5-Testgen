package Testgen::Config;
use strict;
use warnings;

use Carp ();
use File::Spec ();

use Testgen::Util ();

sub new {
    my ($class, $file) = @_;
    my $conf = do $file or die "Can't load $file: $!";

    _validate($conf);
    _set_default_value($conf);

    bless $conf, $class;
}

sub _validate {
    my $conf = shift;

    _check_mandatory_parameters($conf);

    unless ( Testgen::Util::which($conf->{compiler}) ) {
        Carp::croak("$conf->{compiler} is not found. Check path, permission");
    }

    if (defined $conf->{simulator} && !Testgen::Util::which($conf->{simulator})) {
        Carp::croak("$conf->{simulator} is not found. Check path, permission");
    }

    unless (ref $conf->{size} eq 'HASH') {
        Carp::croak("'size' parameter must be a Hash Reference");
    }

    _check_size_parameters($conf->{size});
}

sub _check_mandatory_parameters {
    my $conf = shift;

    my @mandatory_parameters = qw(compiler testdir size);

    for my $parameter (@mandatory_parameters) {
        unless (exists $conf->{$parameter}) {
            Carp::croak("missing mandatory config parameter '$parameter'");
        }
    }
}

sub _check_size_parameters {
    my $size = shift;
    my @types = ('char', 'short', 'int', 'long');

    for my $type (@types) {
        unless (exists $size->{$type}) {
            Carp::croak("'size' parameter must have '$type' bit-width");
        }
    }
}

sub _set_default_value {
    my $conf = shift;

    $conf->{lang}      ||= 'c';
    $conf->{c_flags}   ||= [];
    $conf->{ld_flags}  ||= [];
    $conf->{simulator} ||= undef;
    $conf->{options}   ||= [ '' ];

    $conf->{has_printf}   ||= 1;
    $conf->{expect}       ||= '@OK@';

    $conf->{color}        ||= 0;
    $conf->{parallels}    ||= 1;
    $conf->{complement}   ||= 2;
    $conf->{compile_only} ||= 0;
    $conf->{timeout}      ||= 10;
}

sub get {
    my ($self, $param) = @_;

    unless (exists $self->{$param}) {
        return undef;
    }

    return $self->{$param};
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Config - Testgen config file class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Config->new($config_file) >>

The constructor takes one argument, config file name.
The config file is just perl file, it contains a hashref.
Every key of hashref must be lower-cased.

The config file is like this:

    +{
        compiler  => 'mips-linux-elf-gcc',
        simulator => 'mips-linux-elf-run',
        ...
    };

=head2 Instance Methods

=head3 C<< $config->get(parameter) >>

Gets parameter in configuration file and returns its value.
If paramter is not found in config, then return C<undef>.

=head1 SEE ALSO

F<README>

=cut
