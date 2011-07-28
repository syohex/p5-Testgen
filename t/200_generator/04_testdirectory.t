use strict;
use warnings;

use Test::More;

use Testgen::TestDirectory;

{
    my $testdir = Testgen::TestDirectory->new(
        name => 'test_directory',
    );
    ok($testdir);
    isa_ok($testdir, 'Testgen::TestDirectory');

    is($testdir->{name}, 'test_directory', 'parameter name');
    is_deeply($testdir->{tests}, [], 'parameter tests');
    ok( !defined($testdir->{result_cache}), 'parameter result_cache');
    ok($testdir->{temp_dir}, 'parameter temp_dir');

    can_ok($testdir, 'temp_dir');
    can_ok($testdir, 'tests');

    $testdir->{tests} = [ qw/a b c/ ];
    my @files = $testdir->tests;
    is_deeply(\@files, [ qw/a b c/ ]);
}

{
    eval {
        my $testdir = Testgen::TestDirectory->new();
    };
    like $@, qr/missing mandatory parameter 'name'/, 'constructor without name';
}

done_testing;
