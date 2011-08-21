package Testgen::Runner::Compiler::Result;
use strict;
use warnings;

use base qw/Testgen::Runner::Result/;
use Carp ();

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    my $status = $self->status;
    unless ($status eq 'success' || $status eq 'warn'
            || $status eq 'error') {
        Carp::croak("Invalid status parameter '$status'");
    }

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
----- Compile $self->{status} message -----
$self->{message}
-----------------------------------
...
}

sub is_warn {
    shift->{status} eq 'warn';
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Compiler::Result - A compile command result.

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Compiler::Result->new(%args) >>

Creates and returns a new Testgen::Runner::Compiler::Result with I<%args>.
Dies on error.

I<%args> might be:

=over

=item status :Str

I<status> must be 'success' or 'warn' or 'error'.

=item command :Str

=item message :Str

=back

=head2 Instanse Methods

=head3 C<< $compile_result->message() >> :Str

Return message indicated by the compiler.
Return C<''> when compiling is success.

=head3 C<< $compile_result->is_warn >> :Bool

Return true if the compiler says warning.
C<is_success> and C<is_error> are defined in F<Testgen::Runner::Result>.

=head1 SEE ALSO

L<Testgen::Runner::Result>

=cut
