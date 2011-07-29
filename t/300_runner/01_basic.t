use strict;
use warnings;

use Test::More;

use File::Copy;
use File::Temp;
use Testgen::Runner;

my ($fh, $runconf) = File::Temp::tempfile( UNLINK => 1 );
File::Copy::copy('tgen.cnf', $runconf) or die "Can't copy tgen.cnf";

my $tempdir = File::Temp::tempdir( CLEANUP => 1 );

{
    my $generator = Testgen::Runner->new(
        config_file => $runconf,
        log_dir     => $tempdir,
    );
    ok($generator, 'constructer');
    isa_ok($generator, 'Testgen::Runner');

    is($generator->{log_dir}, $tempdir, "'log_dir' value");
}

{
    my $generator = Testgen::Runner->new(
        config_file => $runconf,
        log_dir     => $tempdir,
    );
    can_ok($generator, 'parse_options');

    $generator->parse_options('aaa', 'bbb');
    is_deeply($generator->{argv}, ['aaa', 'bbb'], 'set argv');

    eval {
        $generator->parse_options(qw/--help/);
    };
    like $@, qr/Usage/, 'help option';
}

{
    my $generator = Testgen::Runner->new(
        config_file => $runconf,
        log_dir     => $tempdir,
    );
    can_ok($generator, 'run');
}

{
    my $input = [ '-O0', '-O2' ];

    my @option_lists = Testgen::Runner::_option_list($input);
    my @expected = (['-O0'], ['-O2']);

    is_deeply(\@option_lists, \@expected, 'options list');

    $input = [
        '-O0',
        [
            '-O2',
            [
                '-funroll-looping',
                '-fopenmp',
            ]
        ]
    ];

    @option_lists = Testgen::Runner::_option_list($input);
    @expected = (
        [ '-O0' ],
        [ '-O2', '-funroll-looping' ],
        [ '-O2', '-fopenmp' ],
    );

    is_deeply(\@option_lists, \@expected, 'options list');

    $input = [
        [
            '-O0',
            [ '', '-Wall' ],
        ],
        [
            '-O2',
            [
                '-funroll-looping',
                '-fopenmp',
            ]
        ]
    ];

    @option_lists = Testgen::Runner::_option_list($input);
    @expected = (
        [ '-O0', '' ],
        [ '-O0', '-Wall' ],
        [ '-O2', '-funroll-looping' ],
        [ '-O2', '-fopenmp' ],
    );

    is_deeply(\@option_lists, \@expected, 'options list');

}

done_testing;
