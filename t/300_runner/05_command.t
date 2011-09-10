use strict;
use warnings;

use Test::More;
use t::Util qw/create_tmp_file/;

use Testgen::Runner::Command;
use Testgen::Util;

{
    my $echo_cmd = [ qw/echo hello world/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $echo_cmd,
    );
    ok($cmd);
    isa_ok($cmd, 'Testgen::Runner::Command');

    is($cmd->{command}, $echo_cmd, 'parameter command');
    is($cmd->{timeout}, 0, 'parameter command');
}

my ($true_cmd, $false_cmd, $sleep_cmd);
$true_cmd = 'true' if Testgen::Util::which('true');
$false_cmd = 'false' if Testgen::Util::which('false');
$sleep_cmd = 'sleep' if Testgen::Util::which('sleep');

SKIP: {
    skip "you don't have 'true' command", 2 unless defined $true_cmd;

    my $cmd = Testgen::Runner::Command->new(
        command => [ $true_cmd ],
    );

    my $res = $cmd->_run_with_system;
    is($res->status, 0, "command is succeed with 'system'");

    skip "Windows can't use IPC", 1 if $^O eq 'MSWin32';
    $res = $cmd->_run_with_ipc;
    is($res->status, 0, "command is succeed with 'IPC'");
}

SKIP: {
    skip "you don't have 'false' command", 2 unless defined $false_cmd;
    my $cmd = Testgen::Runner::Command->new(
        command => [ $false_cmd ],
    );

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    ok($status != 0, "command is failed with 'system'");

    skip "Windows cannot use IPC", 1 if $^O eq 'Win32';
    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    ok($status != 0, "command is failed with 'system'");
}

{
    my $echo_cmd = [ qw/echo hello world/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $echo_cmd,
    );

    my $res = $cmd->_run_with_system;
    like($res->stdout, qr/hello world/, "capture stdout with 'system'");

    SKIP: {
        skip "Window cannot use IPC", 1 if $^O eq 'MSWin32';
        $res = $cmd->_run_with_ipc;
        like($res->stdout, qr/hello world/, "capture stdout with 'IPC'");
    }
}

{
    my $unknown_cmd = [ qw/UNKNOWN_CMD/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $unknown_cmd
    );

    # Some error message may be captured.
    my $res = $cmd->_run_with_system;
    ok( length $res->stderr >= 1, "capture stderr with 'system'");

    SKIP: {
        skip "Window cannot use IPC", 1 if $^O eq 'MSWin32';
        $res = $cmd->_run_with_ipc;
        ok( length $res->stderr >= 1, "capture stderr with 'IPC'");
    }
}

SKIP: {
    skip "you don't have 'sleep' command", 2 unless defined $sleep_cmd;

    my $sleep_cmd = [ qw/sleep 2/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $sleep_cmd,
        timeout => 1,
    );
    is($cmd->{timeout}, 1, 'setting timeout parameter');

    my $res = $cmd->_run_with_system;
    ok(!defined($res->status), "timeout occurs using 'system'");

    SKIP: {
        skip "Window cannot use IPC", 1 if $^O eq 'MSWin32';
        $res  = $cmd->_run_with_ipc;
        ok(!defined($res->status), "timeout occurs using 'IPC'");
    }
}

{
    eval {
        my $cmd = Testgen::Runner::Command->new;
    };
    like $@, qr/missing mandatory parameter/, 'constructor without command';

    eval {
        my $cmd = Testgen::Runner::Command->new( command => 'echo foo');
    };
    like $@, qr/parameter should be ArrayRef/, 'command is not ArrayRef';
}

done_testing;
