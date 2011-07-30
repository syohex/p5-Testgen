use strict;
use warnings;

use Test::More;

use Testgen::Parser;

{
    can_ok('Testgen::Parser', 'create_parser');
    my $cparser = Testgen::Parser->create_parser(
        lang     => 'c',
    );
    ok($cparser);
    isa_ok($cparser, 'Testgen::Parser::CParser');
}

done_testing;
