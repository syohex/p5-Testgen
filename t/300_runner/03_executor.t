use strict;
use warnings;

use Test::More;

use Testgen::Runner::Executor;

{
    my $executor = Testgen::Runner::Executor->new(
        simulator  => 'run',
        has_printf => 0,
        timeout    => 100,
        expect     => '#OK#',
    );
    ok($executor, 'constructer');
    isa_ok($executor, 'Testgen::Runner::Executor');

    is($executor->{simulator}, 'run', "'simulator' value");
    is($executor->{has_printf}, 0, "'has_printf' value");
    is($executor->{timeout}, 100, "'timeout' value");
    is($executor->{expect}, '#OK#', "'expect' value");

    my $executor2 = Testgen::Runner::Executor->new();
    ok( !defined $executor2->{simulator}, "'simulator' default value");
    is($executor2->{has_printf}, 1, "'has_printf' default value");
    is($executor2->{timeout}, 10, "'timeout' default value");
    is($executor2->{expect}, '@OK@', "'expect' default value");
}

{
    my $executor = Testgen::Runner::Executor->new();
    can_ok($executor, 'execute');

    my @cmd = $executor->_create_cmd('a.out');
    my $expected = $^O eq 'MSWin32' ? 'a.out' : './a.out';
    is_deeply(\@cmd, [ $expected ], 'execute directly');

    my $executor2 = Testgen::Runner::Executor->new( simulator => 'run');
    my @cmd2 = $executor2->_create_cmd('a.out');
    is_deeply(\@cmd2, ['run', 'a.out'], 'execute with simulator');
}

done_testing;
