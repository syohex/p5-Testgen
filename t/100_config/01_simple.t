use strict;
use warnings;

use Test::More;
use File::Temp ();
use Data::Dumper;

use Testgen::Config;

my $test_config = {
    compiler      => 'gcc',
    simulator     => undef,
    c_flags       => [ '-g', '-Dunix' ],
    ld_flags      => [ '' ],
    options       => [ '-O0', '-O2' ],
    testdir       => 'testsuite',
    compile_only  => 0,

    size => {
         char  => 8,
         short => 16,
         int   => 32,
         long  => 64,
    },

    timeout       => 10,
    parallels     => 2,
};

my ($fh, $filename) = File::Temp::tempfile();
print {$fh} Data::Dumper::Dumper($test_config);
close $fh;

my $config = Testgen::Config->new($filename);
ok($config);
isa_ok($config, 'Testgen::Config');
can_ok($config, 'get');

for my $key ( keys %{$test_config} ) {
    my $got = $config->get($key);
    my $expected = $test_config->{$key};
    if (ref $got) {
        is_deeply($got, $expected, "set param $key");
    } else {
        is($got, $expected, "set param $key");
    }
}

my %defaults = (
    complement => 2,
);
for my $key ( qw/complement/ ) {
    my $got = $config->get($key);
    my $expected = $defaults{$key};

    if (ref $got) {
        is_deeply($got, $expected, "set default param $key");
    } else {
        is($got, $expected, "set default param $key");
    }
}

done_testing;
