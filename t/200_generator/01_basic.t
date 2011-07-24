use strict;
use warnings;

use Test::More;
use Testgen::Generator;

{
    my $generator = Testgen::Generator->new();
    ok($generator, 'constructer');
    isa_ok($generator, 'Testgen::Generator');
}

{
    my $generator = Testgen::Generator->new();

    $generator->parse_options(qw/--config=test.cnf/);

    is($generator->{config_file}, 'test.cnf', 'config option');

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

done_testing;
