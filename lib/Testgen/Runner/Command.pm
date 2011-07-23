package Testgen::Runner::Command;
use strict;
use warnings;

use Carp ();
use Symbol ();
use IPC::Open3 ();
use IO::Select ();

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
