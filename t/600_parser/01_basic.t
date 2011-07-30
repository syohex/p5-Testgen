use strict;
use warnings;

use Test::More;

use Testgen::Parser;

can_ok('Testgen::Parser', 'create_parser');

{
    eval {
        my $parser = Testgen::Parser->create_parser();
    };
    like $@, qr/missing mandatory parameter/, "constructor without 'lang' parameter";

    eval {
        my $parser = Testgen::Parser->create_parser( lang => 'hogehoge' );
    };
    like $@, qr/parser is not implemented yet/, "not exist parser";
}

done_testing;
