use strict;
use warnings;

use Test::More;

use Testgen::TestDirectory::Test;

{
    my $oknum = Testgen::TestDirectory::Test::_count_ok('');
    is($oknum, 0, 'count printok()');

    $oknum = Testgen::TestDirectory::Test::_count_ok(<<'...');
printok();          printok(            );
printok();
          printok()   printok(5)
...
    is($oknum, 4, 'count printok()');

    $oknum = Testgen::TestDirectory::Test::_count_ok(<<'...');
    /** test info **
     OK: 10
    */
...
    is($oknum, 10, "read from 'test info'");

    eval {
        $oknum = Testgen::TestDirectory::Test::_count_ok(<<'...');
    /** test info **
    */
...
    };
    like $@, qr/Invalid 'test info' section/, "invalid 'test info'";
}

done_testing;
