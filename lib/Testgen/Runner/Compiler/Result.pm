package Testgen::Runner::Compiler::Result;
use strict;
use warnings;

use base qw/Testgen::Runner::Result/;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    my $status = $self->status;
    unless ($status eq 'success' || $status eq 'warn'
            || $status eq 'error') {
        Carp::croak("Invalid status parameter '$status'");
    }

    if ($status eq 'warn' || $status eq 'error') {
        unless (exists $args{message}) {
            Carp::croak("not specified paremeter 'message'");
        }
    }

    return $self;
}

sub message {
    my $self = shift;

    my $status = $self->{status};
    if ($status eq 'success') {
        return '';
    } elsif ($status eq 'warn') {
        return $self->_warn_message();
    } elsif ($status eq 'error') {
        return $self->_error_message();
    }
}

sub _warn_message {
    my $self = shift;

    my $str = $self->{message};
    return <<"...";
----- compile warning message -----
$str
-----------------------------------
...
}

sub _error_message {
    my $self = shift;

    my $str = $self->{message};
    return <<"...";
----- compile error message -----
$str
---------------------------------
...
}

sub is_warning {
    shift->{status} eq 'warn';
}

sub is_error {
    shift->{status} eq 'error';
}

1;
