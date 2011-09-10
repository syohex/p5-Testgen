use strict;
use warnings;

use Test::More;

use Testgen::Merger;

use Cwd ();
use File::Spec ();

{
    my $merger = Testgen::Merger->new();
    ok($merger);
    isa_ok($merger, 'Testgen::Merger');

    ok( !defined($merger->{help}), 'parameter help');
    is($merger->{config_file}, 'runtest.cnf', 'parameter config_file');
    my $expected_dir = File::Spec->catfile(Cwd::getcwd, 'merged');
    is($merger->{output_dir}, $expected_dir, 'parameter output_dir');
    ok('ckr1-1' =~ $merger->{match_regexp}, 'parameter match_regexp');
}

{
    my $merger = Testgen::Merger->new();
    can_ok($merger, 'parse_options');

    my @args = qw/--config=new.conf --output-dir=foo ^c89/;
    $merger->parse_options(@args);

    is($merger->{config_file}, 'new.conf', 'CLI option config_file');
    my $expected_dir = File::Spec->catfile(Cwd::getcwd, 'foo');
    is($merger->{output_dir}, $expected_dir, 'CLI option output_dir');
    ok('c89-100' =~ $merger->{match_regexp}, 'CLI regexp argument');

    eval {
        my $merger = Testgen::Merger->new();
        $merger->parse_options(qw/--help/);
    };
    like $@, qr/Usage/, 'option help';
}

{
    my $merger = Testgen::Merger->new();
    can_ok($merger, 'run');
}

done_testing;
