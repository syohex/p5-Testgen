use strict;
use warnings;

use Test::More;
use Testgen::Util ();

use File::Spec ();
use File::Temp ();
use Cwd ();
use bignum;
use POSIX ();

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
    my ($signed_min, $signed_max) = Testgen::Util::get_type_limit(
        type       => 'long long',
        bit_width  => 32,
        unsigned   => 0,
        complement => 2,
    );

    my $expected_min = -(2 ** 31);
    is($signed_min, $expected_min, "min value");

    my $expected_max = ((2 ** 31) - 1);
    is($signed_max, $expected_max, "max value");

    ($signed_min, undef) = Testgen::Util::get_type_limit(
        type       => 'long long',
        bit_width  => 32,
        unsigned   => 0,
        complement => 1,
    );

    $expected_min = -((2 ** 31) - 1);
    is($signed_min, $expected_min, "max value in 1 complement");

    my ($unsigned_min, $unsigned_max) = Testgen::Util::get_type_limit(
        type       => 'int',
        bit_width  => 32,
        unsigned   => 1,
        complement => 2,
    );

    is($unsigned_min, 0, "unsigned min value");

    $expected_max = ((2 ** 32) - 1);
    is($unsigned_max, $expected_max, "unsigned max value");

    my ($float_min, $float_max) = Testgen::Util::get_type_limit(
        type       => 'float',
        bit_width  => 32,
    );

    is($float_min, POSIX::FLT_MIN, "float min value");
    is($float_max, POSIX::FLT_MAX, "float max value");
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
