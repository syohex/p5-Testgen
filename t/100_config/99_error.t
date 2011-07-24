use strict;
use warnings;

use Test::More;

use Testgen::Config;
use t::Util qw/create_configfile/;

{
    eval {
        my $config = Testgen::Config->new("NOT_FOUND");
    };
    like $@, qr/Can't load/, 'not exist config file';
}

{
    my $no_compiler = {
        testdir => 'testsuite',
        size => {
            char  => 8,
            short => 16,
            int   => 32,
            long  => 64,
        },
    };

    my $conf_file = create_configfile($no_compiler);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/missing mandatory config parameter 'compiler'/, 'no compiler';
}

{
    my $no_testdir = {
        compiler => 'gcc',
        size => {
            char  => 8,
            short => 16,
            int   => 32,
            long  => 64,
        },
    };

    my $conf_file = create_configfile($no_testdir);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/missing mandatory config parameter 'testdir'/, 'no testdir';
}

{
    my $no_size = {
        compiler => 'gcc',
        testdir => 'testsuite',
    };

    my $conf_file = create_configfile($no_size);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/missing mandatory config parameter 'size'/, 'no size';
}

{
    my $not_found_compiler = {
        compiler => 'NOT_FOUND',
        testdir => 'testsuite',
        size => {
            char  => 8,
            short => 16,
            int   => 32,
            long  => 64,
        },
    };

    my $conf_file = create_configfile($not_found_compiler);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/is not found. Check path, permission/, 'compiler not found';
}

{
    my $not_found_simulator = {
        compiler  => 'gcc',
        simulator => 'NOT_FOUND',
        testdir => 'testsuite',
        size => {
            char  => 8,
            short => 16,
            int   => 32,
            long  => 64,
        },
    };

    my $conf_file = create_configfile($not_found_simulator);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/is not found. Check path, permission/, 'simulator not found';
}

{
    my $invalid_size_ref = {
        compiler => 'gcc',
        testdir => 'testsuite',
        size => 'not_hashref',
    };

    my $conf_file = create_configfile($invalid_size_ref);
    eval {
        my $config = Testgen::Config->new($conf_file->filename);
    };
    like $@, qr/'size' parameter must be a Hash Reference/, 'invalid size ref';
}


done_testing;
