use strict;
use warnings;

use Test::More;

use Testgen::Config;
use t::Util qw/create_configfile/;

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

my $conf_file = create_configfile($test_config);

my $config = Testgen::Config->new($conf_file->filename);
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

done_testing;
