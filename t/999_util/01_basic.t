use strict;
use warnings;

use Test::More;
use Testgen::Util ();

use File::Spec ();
use File::Temp ();
use Cwd ();

{
    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $test_file = File::Spec->catfile($tempdir, 'a.txt');
    open my $fh, '>', $test_file or die "Can't open $test_file";
    print {$fh} "hello_world";
    close $fh;

    my @files = Testgen::Util::read_directory($tempdir);
    is_deeply(\@files, [ 'a.txt' ],'read_directory');

    eval {
        my @a = Testgen::Util::read_directory('NOTFOUND');
    };
    like $@, qr/Can't open directory/, 'directory not found';
}

{
    eval {
        my $oknum = Testgen::Util::count_ok_from_file('NOTFOUND');
    };
    like $@, qr/Can't open/, 'file not found';
}

{
    my $oknum = Testgen::Util::_count_ok('');
    is($oknum, 0, 'count printok()');

    $oknum = Testgen::Util::_count_ok(<<'...');
printok();          printok(            );
printok();
          printok()   printok(5)
...
    is($oknum, 4, 'count printok()');

    $oknum = Testgen::Util::_count_ok(<<'...');
    /** test info **
     OK: 10
    */
...
    is($oknum, 10, "read from 'test info'");

    eval {
        $oknum = Testgen::Util::_count_ok(<<'...');
    /** test info **
    */
...
    };
    like $@, qr/Invalid 'test info' section/, "invalid 'test info'";
}

{
    my $cwd1 = Cwd::realpath( Cwd::getcwd() );
    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $guard = Testgen::Util::Chdir->new($tempdir);
    ok($guard, 'constructor');
    isa_ok($guard, 'Testgen::Util::Chdir');

    my $cwd2 = Cwd::realpath( Cwd::getcwd() );
    is(Cwd::realpath($tempdir), $cwd2, 'chdir');

    undef $guard;
    my $cwd3 = Cwd::realpath( Cwd::getcwd() );
    is($cwd1, $cwd3, 'after DESTROY');

    eval {
        my $guard = Testgen::Util::Chdir->new('NOTFOUND');
    };
    like $@, qr/Can't chdir/, 'chdir to not exist directory';
}

done_testing;
