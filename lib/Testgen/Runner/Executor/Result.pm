package Testgen::Runner::Executor::Result;
use strict;
use warnings;

use base qw/Testgen::Runner::Result/;
use Carp ();

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    my $status = $self->status;
    unless ($status eq 'success' || $status eq 'timeout'
            || $status eq 'missing' || $status eq 'error') {
        Carp::croak("Invalid status parameter '$status'");
    }

    $self->{ratio} ||= '0/0';

    return $self;
}

sub message {
    my $self = shift;
    return $self->is_success ? '' : $self->_indicated_message;
}

sub _indicated_message {
    my $self = shift;

    return <<"...";
$self->{command}
----- Execute $self->{status} message ($self->{ratio}) -----
$self->{message}
-----------------------------------
...
}

sub is_missing {
    shift->{status} eq 'missing';
}

sub is_timeout {
    shift->{status} eq 'timeout';
}

1;

=encoding utf8

=head1 NAME

Testgen::Runner::Executor::Result - Result class of Execute command.

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Executor::Result->new(%args) >>

Creates and returns a new Testgen::Runner::Executor::Result with I<%args>.
Dies on error.

I<%args> might be:

=over

=item status :Str

I<status> must be 'success' or 'missing' or 'timeout' or 'error'.

=item command :Str

=item message :Str

=back

=head2 Instanse Methods

=head3 C<< $execute_result->message() >> :Str

Return message indicated by system or simlator.
Return C<''> when executing is success.

=head3 C<< $execute_result->is_missing >> :Bool

Return true if the 'ok' count is different from expected.

=head3 C<< $execute_result->is_timeout >> :Bool

Return true if timeout happen 'ok', while executing binary.

C<is_success> and C<is_error> are defined in F<Testgen::Runner::Result>.

=head1 SEE ALSO

L<Testgen::Runner::Result>

=cut
