package Testgen::ForkManager;
use strict;
use warnings;

use Carp ();
use POSIX ();

# This code is minimized 'Parallel::ForkManager'

sub new {
    my ($class, $maxprocs) = @_;

    if ($maxprocs < 1) {
        Carp::croak("'maxprocs' must be larger than 0");
    }

    bless {
        maxprocs  => $maxprocs || 1,
        processes => {},
    }, $class;
}

sub start {
    my $self = shift;

    while (( keys %{$self->{processes}} ) >= $self->{maxprocs}) {
        $self->_wait_one_child;
    }

    $self->_wait_children;

    my $pid = fork;
    Carp::croak("Cannot fork $!") unless defined $pid;

    if ($pid) {
        # parent
        $self->{processes}->{$pid} = 1;
    } else {
        # child
        $self->{in_child} = 1;
    }

    return $pid;
}

sub _wait_one_child {
    my ($self, $flag) = @_;

    my $kid;
    if ($kid = waitpid(-1, $flag || 0)) {
        delete $self->{processes}->{$kid};
    }

    return $kid;
}

sub _wait_children {
    my $self = shift;
    return if (scalar keys %{$self->{processes}}) == 0;

    my $kid;
    do {
        $kid = $self->_wait_one_child(POSIX::WNOHANG);
    } while ($kid > 0);
}

sub wait_all_children {
    my $self = shift;

    while ( keys %{$self->{processes}} ) {
        $self->_wait_one_child;
    }
}

sub finish {
    my $self = shift;

    unless (defined $self->{in_child}) {
        Carp::croak("parent process cannot call 'finish' method");
    }

    CORE::exit(0);
}

1;

__END__

=encoding utf8

=for stopwords

=head1 NAME

Testgen::ForkManager - A simple fork manager.

=head1 SYNOPSIS

  use Testgen::ForkManager;

  my $fm = Testgen::ForkManager->new(10); # maxproc = 10
  for my $task (@tasks) {
      my $pid = $fm->start and next;

      ... process task

      $fm->finish; # terminate child process
  }

  $fm->wait_all_children; # wait all child processes


=head1 DESCRIPTION

Testgen::ForkManager is a simple fork manager. This code is minimized
L<Parallel::ForkManager>. I implement features of B<fork> and B<wait>
in L<Parallel::ForkManager>. Other features are not implemented.

=head1 AUTHOR

dLux (Szabo, Balazs) <dlux@dlux.hu>

=head1 COPYRIGHT

Copyright (c) 2000-2010 Szabo, Balazs (dLux)

All right reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Parallel::ForkManager>

=cut
