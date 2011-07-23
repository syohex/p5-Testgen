package Testgen::Runner::Result;
use strict;
use warnings;

use Carp ();

sub new {
    my ($class, %args) = @_;

    for my $param ( qw/status command message/ ) {
        unless (exists $args{$param}) {
            Carp::croak("missing mandatory parameter '$param'");
        }
    }

    bless {
        %args,
    }, $class;
}

# accessor
sub status  { shift->{status}  }
sub command { shift->{command} }
sub message { shift->{message} }

sub is_success {
    shift->{status} eq 'success';
}

sub is_error {
    shift->{status} eq 'error';
}

1;
