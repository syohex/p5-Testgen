use strict;
use warnings;

use Test::More;
use Testgen::Generator;

{
    my $generator = Testgen::Generator->new();
    ok($generator, 'constructer');
    isa_ok($generator, 'Testgen::Generator');

    is($generator->{config_file}, 'tgen.cnf', 'default value');
}

{
    my $generator = Testgen::Generator->new();
    can_ok($generator, 'parse_options');

    $generator->parse_options(qw/--config=test.cnf/);
    is($generator->{config_file}, 'test.cnf', 'config option');

    $generator->parse_options(qw/--int-only/);
    ok($generator->{int_only}, 'int only option');

    my $generator2 = Testgen::Generator->new();
    $generator2->parse_options(qw/--float-only/);
    ok($generator2->{float_only}, 'float only option');

    eval {
        $generator->parse_options(qw/--help/);
    };
    like $@, qr/Usage/, 'help option';

    eval {
        $generator->parse_options(qw/-i -f/);
    };
    like $@, qr/Cannot enable 'int-only' and 'float-only' option/,
          'specified int-only and float-only option';
}

{
    my $generator = Testgen::Generator->new();
    can_ok($generator, 'run');
}

done_testing;
