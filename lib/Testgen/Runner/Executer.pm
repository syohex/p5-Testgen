package Testgen::Runner::Executer;
use strict;
use warnings;

use Testgen::Runner::Command;
use Testgen::Runner::Executer::Result;

sub new {
    my ($class, %args) = @_;

    my $has_printf = delete $args{has_printf} || 1;
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
        return Testgen::Runner::Executer::Result->new(
            command => "@cmd",
            message => "timeout: " . $test->input,
            status  => 'timeout',
        );
    }

    my $result;
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
