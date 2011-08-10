use strict;
use warnings;

use Test::More;

use Testgen::Runner::Compiler::Result;
use Testgen::Runner::Executor::Result;

{
    my $result = Testgen::Runner::Compiler::Result->new(
        status  => 'success',
        command => "gcc hello.c",
        message => 'success compiling',
    );
    ok($result, 'constructor');
    isa_ok($result, 'Testgen::Runner::Compiler::Result');
    is($result->{status}, 'success', 'parameter status');
    is($result->{command}, 'gcc hello.c', 'parameter command');
    is($result->{message}, 'success compiling', 'parameter message');

    can_ok($result, 'message');
    is($result->message, '', 'success message');
    can_ok($result, 'is_success');
    can_ok($result, 'is_warn');
    can_ok($result, 'is_error');
    ok($result->is_success);
    ok(!$result->is_warn);
    ok(!$result->is_error);

    my $error = Testgen::Runner::Compiler::Result->new(
        status  => 'error',
        command => "gcc hello.c",
        message => 'fail compiling',
    );

    my $expected = <<'...';
gcc hello.c
----- Compile error message -----
fail compiling
-----------------------------------
...

    is($error->message, $expected, 'error message');
    ok($error->is_error);

    my $warn= Testgen::Runner::Compiler::Result->new(
        status  => 'warn',
        command => "gcc hello.c",
        message => 'warning compiling',
    );

    $expected = <<'...';
gcc hello.c
----- Compile warn message -----
warning compiling
-----------------------------------
...
    is($warn->message, $expected, 'warn message');
    ok($warn->is_warn);

}

{
    eval {
        my $result = Testgen::Runner::Compiler::Result->new(
            status  => 'unknown',
            command => 'gcc a.c',
            message => 'foo',
        );
    };
    like $@, qr/Invalid status parameter/, 'invalid status';
}

{
    my $result = Testgen::Runner::Executor::Result->new(
        status  => 'missing',
        command => "run a.out",
        message => 'missing @OK@ number',
    );
    ok($result, 'constructor');
    isa_ok($result, 'Testgen::Runner::Executor::Result');
    is($result->{ratio}, '0/0', 'default value');
}

{
    eval {
        my $result = Testgen::Runner::Compiler::Result->new(
            status  => 'unknown',
            command => 'run a.out',
            message => 'bar',
        );
    };
    like $@, qr/Invalid status parameter/, 'invalid status';
}

done_testing;
