package Testgen::Runner::Executer::Result;
use strict;
use warnings;

use base qw/Testgen::Runner::Result/;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    my $status = $self->status;
    unless ($status eq 'success' || $status eq 'timeout'
            || $status eq 'missing' || $status eq 'error') {
        Carp::croak("Invalid status parameter '$status'");
    }

    return $self;
}

sub message {
    my $self = shift;

    my $status = $self->{status};
    if ($status eq 'success') {
        return '';
    } elsif ($status eq 'missing') {
        return $self->_missing_message();
    } elsif ($status eq 'timeout') {
        return $self->_timeout_message();
    }
}

sub _missing_message {
    my $self = shift;

    my $str = $self->{message};
    return <<"...";
----- execute missing message -----
$str
-----------------------------------
...
}

sub _timeout_message {
    my $self = shift;

    my $str = $self->{message};
    return <<"...";
----- execute timeout message -----
$str
-----------------------------------
...
}

1;
