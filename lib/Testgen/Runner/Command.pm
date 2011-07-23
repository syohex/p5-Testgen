package Testgen::Runner::Command;
use strict;
use warnings;

use Carp ();
use Encode ();
use File::Temp ();
use Symbol ();
use IPC::Open3 ();
use IO::Select ();

our $HAS_MULTICORE = 0;
my $encoder = Encode::find_encoding('utf8');

sub new {
    my ($class, %args) = @_;

    unless (exists $args{command}) {
        Carp::croak("missing mandatory parameter 'command'");
    }

    unless (ref $args{command} eq 'ARRAY') {
        Carp::croak("'command' parameter should be ArrayRef");
    }

    my $timeout = delete $args{timeout} || 0;

    bless {
        timeout => $timeout,
        %args,
    }, $class;
}

sub run {
    my $self = shift;

    if ($HAS_MULTICORE && $^O ne 'MSWin32') {
        return $self->_run_with_system();
    } else {
        return $self->_run_with_ipc();
    }
}

sub _run_with_system {
    my $self = shift;

    my ($ofh, $out_redirect) = File::Temp::tempfile( UNLINK => 1 );
    my ($efh, $err_redirect) = File::Temp::tempfile( UNLINK => 1 );
    my @cmd = @{$self->{command}};

    # [CAUTION] This use of 'system' is very insecure !!!!
    # I don't understand why using IPC is too slow.
    my $status = system( "@cmd" . " > $out_redirect 2> $err_redirect" );

    my ($stdout, $stderr) = do {
        local $/;
        map { $encoder->decode($_) } (scalar <$ofh>, scalar <$efh>);
    };
    close $efh;
    close $ofh;

    return ( $status, $stdout, $stderr );
}

sub _run_with_ipc {
    my $self = shift;

    my ($out_fh, $err_fh) = (Symbol::gensym, Symbol::gensym);
    my $pid = IPC::Open3::open3(undef, $out_fh, $err_fh, @{$self->{command}});

    my $watcher = IO::Select->new();
    $watcher->add($out_fh);
    $watcher->add($err_fh);

    my $timeout = $self->{timeout};
    my ($stdout, $stderr) = ('', '');
    while ($watcher->count > 0) {
        my @ready;
        while ( @ready = $watcher->can_read($timeout) ) {
            for my $fh ( @ready ) {
                my $bytes = sysread $fh, my $buf, 4096;
                if ($bytes == -1) {
                    Carp::croak("read error $!");
                } elsif ($bytes == 0) {
                    $watcher->remove($fh);
                } else {
                    if ($fh == $out_fh) {
                        $stdout .= $buf;
                    } else {
                        $stderr .= $buf;
                    }
                }
            }
        }
        if ($timeout && $watcher->count > 0 && !@ready) {
            kill 'TERM' => $pid;
            waitpid $pid, 0;
            return (undef, $stdout, $stderr);
        }
    }

    waitpid $pid, 0;
    return ( ($? >> 8), $stdout, $stderr);
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Command - A Testgen command class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Command->new(%args) :Testgen::Runner::Command >>

Creates and returns a new Testgen::Runner::Command object with I<args>.
Dies on error.

I<%args> might be:

=over

=item command :ArrayRef

=item timeout :Int = 0

Timeout never happen by default.

=back

=head2 Package Variable

=head3 C<< $Testgen::Runner::Command::HAS_MULTICORE >>

If this variable is true, host machine may be have multicore processors.
Default is false. On MicroSoft Windows, this variable is always false.

=head2 Instance Methods

=head3 C<< $command->run() >> :( $exit_status, $stdout, $stderr)

Run command. Return three values, exit_status, output to STDOUT,
output to STDERR.

If timeout happens, C<$exit_status> is C<undef>.

=cut
