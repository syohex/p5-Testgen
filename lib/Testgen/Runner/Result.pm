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

sub message { die "'message' method must be override"; }

sub is_success {
    shift->{status} eq 'success';
}

sub is_error {
    shift->{status} eq 'error';
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Result - Base class of command result

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Result->new(%args) >>

Creates and returns a new Testgen::Runner::Result with I<%args>.
Dies on error.

You should call this method from sub class, not call directly.

I<%args> might be:

=over

=item status :Str

=item command :Str

=item message :Str

=back

=head2 Instance Methods

=head3 C<< $result->is_success >> :Bool

Return true if the compiling is success.

=head3 C<< $result->is_error >> :Bool

Return true if the compiling is fail.

=cut
