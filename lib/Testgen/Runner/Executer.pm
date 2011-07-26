package Testgen::Runner::Executer;
use strict;
use warnings;

use Testgen::Runner::Command;
use Testgen::Runner::Executer::Result;

sub new {
    my ($class, %args) = @_;

    my $has_printf = exists $args{has_printf} ? $args{has_printf} : 1;
    my $timeout    = delete $args{timeout}    || 10;
    my $expect     = delete $args{exepect}    || '@OK@';
    my $simulator  = delete $args{simulator}  || undef;

    bless {
        has_printf => $has_printf,
        timeout    => $timeout,
        expect     => $expect,
        simulator  => $simulator,
        %args,
    }, $class;
}

sub execute {
    my ($self, $test) = @_;

    my @cmd = $self->_create_cmd( $test->output );
    my $command = Testgen::Runner::Command->new(
        command => \@cmd,
        timeout => $self->{timeout},
    );

    my ($exit_status, $stdout) = $command->run;

    unless (defined $exit_status) {
        # Timeout happens
        return Testgen::Runner::Executer::Result->new(
            command => "@cmd",
            message => "timeout: " . $test->input,
            status  => 'timeout',
        );
    }

    my $result;
    my $ratio = '';
    if ($exit_status == 0 ) {
        if ($self->{has_printf}) {
            my $expect = quotemeta $self->{expect};
            my $oknum = 0;
            $oknum += 1 while $stdout =~ m{$expect}gxms;

            if ($oknum == $test->oknum) {
                $result = 'success';
            } else {
                $result = 'missing';
            }
            $ratio = join '/', $oknum, $test->oknum;
        } else {
            $result = 'success';
        }
    } else {
        $result = 'error';
    }

    return Testgen::Runner::Executer::Result->new(
        command => "@cmd",
        status  => $result,
        message => $stdout,
        ratio   => $ratio,
    );
}

sub _create_cmd {
    my ($self, $executable) = @_;

    if (defined $self->{simulator}) {
        return ($self->{simulator}, $executable);
    } else {
        return ("./${executable}");
    }
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Executer - A executer class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Executer->new(%args) :Testgen::Runner::Executer >>

Creates and returns a new Testgen::Runner::Executer object with I<args>.

I<%args> might be:

=over

=item has_printf :Bool = true

=item timeout :Int = 10

=item expect : Str = '@OK@'

=item simulator :Str = undef

=back

=head2 Instance Methods

=head3 C<< $executer->execute($test) >>

Execute test which is a F<Testgen::Runner::Testdirectory::Test>.
Return a L<Testgen::Runner::Executer::Result> object.

=cut
