use strict;
use warnings;

use Test::More;

use Testgen::Runner::Compiler;
use Testgen::TestDirectory::Test;
use Testgen::Util;
use t::Util qw(create_tmp_file);

{
    my $compiler = Testgen::Runner::Compiler->new(
        name     => 'clang',
        c_flags  => ['-g', '-Dlinux'],
        ld_flags => ['-lm']
    );
    ok($compiler, 'constructer');
    isa_ok($compiler, 'Testgen::Runner::Compiler');

    is($compiler->{name}, 'clang', "'compiler' value");
    is_deeply($compiler->{c_flags}, ['-g', '-Dlinux'], "'c_flags' value");
    is_deeply($compiler->{ld_flags}, ['-lm'], "'ld_flags' value");

    my $compiler2 = Testgen::Runner::Compiler->new( name => 'pcc');
    is_deeply($compiler2->{c_flags}, [], "'c_flags' default value");
    is_deeply($compiler2->{ld_flags}, [], "'ld_flags' default value");
    is_deeply($compiler2->{output_option}, '-o', "'output_option' default value");
    is_deeply($compiler2->{option_separator}, ' ', "'option_separator' default value");
}

{
    my $compiler = Testgen::Runner::Compiler->new(
        name     => 'gcc',
        c_flags  => ['-g'],
        ld_flags => ['-lgcc'],
    );
    can_ok($compiler, 'compile');

    my @cmd = $compiler->_compile_command('a.c', 'a.out', '-O2', '-ansi');
    is_deeply(\@cmd,
              ['gcc', '-g', '-O2', '-ansi', 'a.c', '-o', 'a.out', '-lgcc'],
              'compile command');

    my $compiler2 = Testgen::Runner::Compiler->new(
        name     => 'cl.exe',
        output_option => '/Fe',
        option_separator => '',
    );

    my @cmd2 = $compiler2->_compile_command('a.c', 'a.out', '/O2');
    is_deeply(\@cmd2,
              ['cl.exe', '/O2', 'a.c', '/Fea.out'],
              'compile command specified option separator');
}

my $compiler;
$compiler = 'gcc' if Testgen::Util::which('gcc');

SKIP: {
    skip "you don't have any compiler", 2 unless defined $compiler;

    my $content =<<'...';
#define RETURN_VALUE 10
int main()
{
    return RETURN_VALUE;
}
...
    my $cfile = create_tmp_file(
        suffix  => '.c',
        content => $content,
    );

    my $test = Testgen::TestDirectory::Test->new(
        files => [ $cfile ],
    );

    my $compiler = Testgen::Runner::Compiler->new(
        name     => $compiler,
        c_flags  => ['-c'],
    );

    my ($stdout, $stderr) = $compiler->preprocess($cfile);
    like $stdout, qr/return \s+ 10/x, "proprocessing c file";

    my $result = $compiler->compile($test);
    isa_ok($result, "Testgen::Runner::Compiler::Result");

    $test->finalize;
}

{
    eval {
        my $compiler = Testgen::Runner::Compiler->new;
    };
    like $@, qr/missing mandatory parameter/, "constructor without 'name'";
}

done_testing;
