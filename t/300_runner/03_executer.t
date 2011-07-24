use strict;
use warnings;

use Test::More;

use Testgen::Runner::Executer;

{
    my $executer = Testgen::Runner::Executer->new(
        simulator  => 'run',
        has_printf => 0,
        timeout    => 100,
        expect     => '#OK#',
    );
    ok($executer, 'constructer');
    isa_ok($executer, 'Testgen::Runner::Executer');

    is($executer->{simulator}, 'run', "'simulator' value");
    is($executer->{has_printf}, 0, "'has_printf' value");
    is($executer->{timeout}, 100, "'timeout' value");
    is($executer->{expect}, '#OK#', "'expect' value");

    my $executer2 = Testgen::Runner::Executer->new();
    ok( !defined $executer2->{simulator}, "'simulator' default value");
    is($executer2->{has_printf}, 1, "'has_printf' default value");
    is($executer2->{timeout}, 10, "'timeout' default value");
    is($executer2->{expect}, '@OK@', "'expect' default value");
}

{
    my $executer = Testgen::Runner::Executer->new();
    can_ok($executer, 'execute');

    my @cmd = $executer->_create_cmd('a.out');
    is_deeply(\@cmd, ['./a.out'], 'execute directly');

    my $executer2 = Testgen::Runner::Executer->new( simulator => 'run');
    my @cmd2 = $executer2->_create_cmd('a.out');
    is_deeply(\@cmd2, ['run', 'a.out'], 'execute with simulator');
}

done_testing;
