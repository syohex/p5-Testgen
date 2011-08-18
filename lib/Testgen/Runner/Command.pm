package Testgen::Runner::Command;
use strict;
use warnings;

use Carp ();
use Cwd ();
use Encode ();
use Time::HiRes ();
use File::Temp ();
use Symbol ();
use IO::Select ();

use constant WIN32 => $^O eq 'MSWin32';

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

    if ( WIN32 ) {
        return $self->_run_with_ipc();
    } else {
        return $self->_run_with_system();
    }
}

sub _run_with_system {
    my $self = shift;

    my $cwd = Cwd::getcwd;
    my $ofh = File::Temp->new( DIR => $cwd );
    my $out_redirect = $ofh->filename;

    my $efh = File::Temp->new( DIR => $cwd );
    my $err_redirect = $efh->filename;

    my @cmd = @{$self->{command}};

    ### Hummmmm.
    ##  I want to use IPC for portability, but using IPC makes slow
    ##  and not scaling very much. I don't understand why using IPC
    ##  is too slow. So Unix platform using 'system' instead of IPC.

    my ($status, $run_time);
    eval {
        local $SIG{ALRM} = sub { die "timeout\n"; };
        alarm $self->{timeout} if $self->{timeout};

        my $time_start = [ Time::HiRes::gettimeofday ];
        $status = system( "@cmd > $out_redirect 2> $err_redirect" );
        $run_time = sprintf '%.6f', Time::HiRes::tv_interval($time_start);
        alarm 0;
    };
    if ($@ && $@ eq "timeout\n") {
        my $cmd_str = quotemeta "@cmd";
        my $pid;

        open my $fh, "-|", ('ps', 'x') or Carp::croak("Can't open 'ps x'");
        while (my $line = <$fh>) {
            chomp $line;

            if ($line =~ m{$cmd_str}) {
                $line =~ s{^\s*}{};
                $pid = (split /\s+/, $line)[0];
                last;
            }
        }
        close $fh;

        if (defined $pid) {
            kill 'TERM', $pid;
            waitpid $pid, 0;
        } else {
            Carp::carp("@cmd is maybe finished");
        }

        return Testgen::Runner::Command::Response->new( status => undef );
    }

    my ($stdout, $stderr) = do {
        local $/;
        map { $encoder->decode($_) } (scalar <$ofh>, scalar <$efh>);
    };

    return Testgen::Runner::Command::Response->new(
        status => $status,
        stdout => $stdout,
        stderr => $stderr,
        time   => $run_time,
    );
}

sub _run_with_ipc {
    my $self = shift;

    pipe(my $stdout_r, my $stdout_w);
    pipe(my $stderr_r, my $stderr_w);

    my $time_start = [ Time::HiRes::gettimeofday ];

    my $pid = fork;
    Carp::croak("Can't fork process: $!") unless defined $pid;

    if ($pid == 0) {
        close $stdout_r;
        close $stderr_r;

        open STDOUT, ">&=" . fileno($stdout_w)
            or Carp::croak("Can't dup STDOUT: $!");
        open STDERR, ">&=" . fileno($stderr_w)
            or Carp::croak("Can't dup STDERR: $!");

        exec @{$self->{command}} or Carp::croak("Can't exec: $!");
        exit 2; # Never reach here
    }

    close $stdout_w;
    close $stderr_w;

    my $watcher = IO::Select->new();
    $watcher->add($stdout_r);
    $watcher->add($stderr_r);

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
                    if ($fh == $stdout_r) {
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

            return Testgen::Runner::Command::Response->new(
                status => undef,
                stdout => $encoder->decode($stdout),
                stderr => $encoder->decode($stderr),
            );
        }
    }

    waitpid $pid, 0;
    my $run_time = sprintf '%.6f', Time::HiRes::tv_interval($time_start);

    return Testgen::Runner::Command::Response->new(
        status => ($? >> 8),
        stdout => $encoder->decode($stdout),
        stderr => $encoder->decode($stderr),
        time   => $run_time,
    );
}

package
    Testgen::Runner::Command::Response;

use Carp ();

sub new {
    my ($class, %args) = @_;

    unless (exists $args{status}) {
        Carp::croak("missing mandatory parameter 'status'");
    }

    my $stdout = delete $args{stdout} || '';
    my $stderr = delete $args{stderr} || '';
    my $time   = delete $args{time}   || '-';

    bless {
        stdout => $stdout,
        stderr => $stderr,
        time   => $time,
        %args,
    }, $class;
}

# accessor
sub status { shift->{status} }
sub stdout { shift->{stdout} }
sub stderr { shift->{stderr} }
sub time   { shift->{time}   }

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Command - Testgen command class

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

=head2 Instance Methods

=head3 C<< $command->run() >> :( $exit_status, $stdout, $stderr)

Run command. Return a C<Testgen::Runner::Command::Response> instance.
Its instance has member status, stdout, stderr, time.

If timeout happens, C<$exit_status> is C<undef>.

=cut
