use strict;
use warnings;

use Test::More;

use Testgen::Config;
use t::Util qw/create_configfile/;

my $test_config = {
    compiler      => 'gcc',
    testdir       => 'testsuite',

    size => {
         char  => 8,
         short => 16,
         int   => 32,
         long  => 64,
    },
};

my $conf_file = create_configfile($test_config);
my $config = Testgen::Config->new($conf_file->filename);

my %defaults = (
    complement   => 2,
    c_flags      => [],
    ld_flags     => [],
    simulator    => undef,
    options      => [ '' ],
    has_printf   => 1,
    expect       => '@OK@',
    color        => 0,
    parallels    => 1,
    complement   => 2,
    compile_only => 0,
    timeout      => 10,
);

for my $key ( keys %defaults ) {
    my $got = $config->get($key);
    my $expected = $defaults{$key};

    if (ref $got) {
        is_deeply($got, $expected, "set default param $key");
    } else {
        is($got, $expected, "set default param $key");
    }
}

done_testing;
