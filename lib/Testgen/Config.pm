package Testgen::Config;
use strict;
use warnings;

use Carp ();

sub new {
    my ($class, $file) = @_;
    my $conf = do $file or die "Can't load $file: $!";

    _set_default_value($conf);

    bless $conf, $class;
}

sub _set_default_value {
    my $conf = shift;

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

=encoding utf-8

=head1 NAME

Testgen::Config - Testgen config file object

=head1 CONSTRACTOR

=over 4

=item my $config = Testgen::Config->new($config_file);

The constructor takes one argument, config file name.
The config file is just perl file, it contains a hashref.
Every key of hashref must be lower-cased.

The config file is like this:

    +{
        compiler  => 'mips-linux-elf-gcc',
        simulator => 'mips-linux-elf-run',
    };

=back

Testgen is c test generator

=head1 AUTHOR

Authors of original source code are:

Yuki UCHIYAMA

Kazushi MORIMOTO

Nagisa ISHIURA

Nobuyuki HIKICHI



=cut

