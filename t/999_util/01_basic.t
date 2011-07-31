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
    my @options = (
        [ '-O2' ], [ '', '-funroll-loops'] ,
    );

    my $retval = Testgen::Util::combination( @options );
    my $expected = [ ['-O2', ''], [ '-O2', '-funroll-loops'] ];

    is_deeply($retval, $expected, 'gettin combination');
}

{
    ok(Testgen::Util::which('perl'), "'which' function");
    ok(!Testgen::Util::which('HOGEHOGE'), "not exist command");
}

{
    ok(Testgen::Util::load_class('Testgen'), "'load_class' function");
    ok(!Testgen::Util::load_class('Testgen::NOTFOUND'), "not found class");
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
