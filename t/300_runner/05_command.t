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

my ($true_cmd, $false_cmd);
$true_cmd = 'true' if Testgen::Util::which('true');
$false_cmd = 'false' if Testgen::Util::which('false');

SKIP: {
    skip "you don't have 'true' command", 2 unless defined $true_cmd;

    my $cmd = Testgen::Runner::Command->new(
        command => [ $true_cmd ],
    );

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    is($status, 0, "command is succeed with 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    is($status, 0, "command is succeed with 'IPC'");
}

SKIP: {
    skip "you don't have 'false' command", 2 unless defined $false_cmd;
    my $cmd = Testgen::Runner::Command->new(
        command => [ $false_cmd ],
    );

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    ok($status != 0, "command is failed with 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    ok($status != 0, "command is failed with 'system'");
}

{
    my $echo_cmd = [ qw/echo hello world/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $echo_cmd,
    );

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    is($stdout, "hello world\n", "capture stdout with 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    is($stdout, "hello world\n", "capture stdout with 'IPC'");
}

{
    my $echo_cmd = [ qw/echo hello world/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $echo_cmd,
    );

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    is($stdout, "hello world\n", "capture stdout with 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    is($stdout, "hello world\n", "capture stdout with 'IPC'");
}

{
    my $unknown_cmd = [ qw/UNKNOWN_CMD/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $unknown_cmd
    );

    # Some error message may be captured.
    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    ok( length $stderr >= 1, "capture stderr with 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    ok( length $stderr >= 1, "capture stderr with 'IPC'");
}

{
    my $sleep_cmd = [ qw/sleep 2/ ];
    my $cmd = Testgen::Runner::Command->new(
        command => $sleep_cmd,
        timeout => 1,
    );
    is($cmd->{timeout}, 1, 'setting timeout parameter');

    my ($status, $stdout, $stderr) = $cmd->_run_with_system;
    ok(!defined($status), "timeout occurs using 'system'");

    ($status, $stdout, $stderr) = $cmd->_run_with_ipc;
    ok(!defined($status), "timeout occurs using 'IPC'");
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
