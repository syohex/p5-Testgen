package Testgen::Runner::Command;
use strict;
use warnings;

use Carp ();
use Cwd ();
use Encode ();
use Time::HiRes ();
use File::Temp ();
use POSIX ();
use IPC::Open3 ();

my $encoding = $^O eq 'MSWin32' ? 'cp932' : 'utf8';
my $encoder = Encode::find_encoding($encoding);
my $overhead = do {
    my $start = [ Time::HiRes::gettimeofday ];
    sprintf '%.6f', Time::HiRes::tv_interval($start);
};

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

if ($^O eq 'MSWin32') {
    *run = \&_run_with_system;
} else {
    *run = \&_run_with_ipc;
}

sub _run_with_system {
    my $self = shift;

    my $cwd = Cwd::getcwd;
    my (undef, $out_redirect) = File::Temp::tempfile( DIR => $cwd );
    my (undef, $err_redirect) = File::Temp::tempfile( DIR => $cwd );

    my @cmd = @{$self->{command}};

    my ($status, $run_time, $response);
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

        $response = Testgen::Runner::Command::Response->new( status => undef );

    } else {
        my ($stdout, $stderr) = do {
            local $/;

            open my $ofh, '<', $out_redirect
               or Carp::croak("Can't open $out_redirect: $!");
            open my $efh, '<', $err_redirect
               or Carp::croak("Can't open $err_redirect: $!");
            map { $encoder->decode($_) } (scalar <$ofh>, scalar <$efh>);
        };

        $response = Testgen::Runner::Command::Response->new(
            status => $status,
            stdout => $stdout,
            stderr => $stderr,
            time   => $run_time - $overhead,
        );
    }

    unlink $out_redirect, $err_redirect;
    return $response;
}

sub _run_with_ipc {
    my $self = shift;

    my $cwd = Cwd::getcwd;
    my ($cout, $coutname) = File::Temp::tempfile( DIR => $cwd, UNLINK => 1);
    my ($cerr, $cerrname) = File::Temp::tempfile( DIR => $cwd, UNLINK => 1);

    *COUT = $cout;
    *CERR = $cerr;

    my ($pid, $status, $run_time);
    my $time_start = [ Time::HiRes::gettimeofday ];
    eval {
        $pid = IPC::Open3::open3(my $cin, '>&COUT', '>&CERR', @{$self->{command}});

        local $SIG{ALRM} = sub { die "timeout\n"; };
        alarm $self->{timeout} if $self->{timeout};

        while (waitpid($pid, 0) != $pid) {}
        $run_time = sprintf '%.6f', Time::HiRes::tv_interval($time_start);

        $status = $? >> 8;
        alarm 0;
    };

    if ($@ && $@ eq "timeout\n") {
        kill TERM => $pid;
        waitpid $pid, 0;

        return Testgen::Runner::Command::Response->new(status => undef);
    } elsif ($@) {
        return Testgen::Runner::Command::Response->new(
            status => 1, # If executing command is failed, $? is not set.
            stderr => "$@",
        );
    }

    seek($cout, 0, POSIX::SEEK_SET) or Carp::croak("Can't seek stdout: $!");
    seek($cerr, 0, POSIX::SEEK_SET) or Carp::croak("Can't seek stderr: $!");

    my ($stdout, $stderr) = map {
        local $/;
        <$_>;
    } $cout, $cerr;

    $stdout ||= '';
    $stderr ||= '';

    return Testgen::Runner::Command::Response->new(
        status => ($status >> 8),
        stdout => $encoder->decode($stdout),
        stderr => $encoder->decode($stderr),
        time   => $run_time - $overhead,
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
