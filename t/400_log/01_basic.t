use strict;
use warnings;

use Test::More;
use File::Temp ();

use Testgen::Log;

my $testdir = File::Temp::tempdir( CLEANUP => 1 );
$testdir =~ s{/$}{};

{
    my $log = Testgen::Log->new( dir => $testdir, name => 'test.log' );
    ok(-e File::Spec->catfile($testdir, 'test.log'), 'create log file');

    can_ok($log, 'print');
}

{
    eval {
        my $log = Testgen::Log->new();
    };
    like $@, qr/missing manfdatory 'dir' parameter/, "constructor witout 'dir'";

   eval {
        my $log = Testgen::Log->new( dir => '/tmp', encoding => 'NOTFOUND' );
    };
    like $@, qr/Not found encoding/, "invalid encoding";
}


done_testing;
