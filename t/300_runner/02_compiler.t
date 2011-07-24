use strict;
use warnings;

use Test::More;

use Testgen::Runner::Compiler;

{
    my $compiler = Testgen::Runner::Compiler->new(
        compiler => 'clang',
        c_flags  => ['-g', '-Dlinux'],
        ld_flags => ['-lm']
    );
    ok($compiler, 'constructer');
    isa_ok($compiler, 'Testgen::Runner::Compiler');

    is($compiler->{compiler}, 'clang', "'compiler' value");
    is_deeply($compiler->{c_flags}, ['-g', '-Dlinux'], "'c_flags' value");
    is_deeply($compiler->{ld_flags}, ['-lm'], "'ld_flags' value");

    my $compiler2 = Testgen::Runner::Compiler->new(compiler => 'pcc');
    is_deeply($compiler2->{c_flags}, [], "'c_flags' default value");
    is_deeply($compiler2->{ld_flags}, [], "'ld_flags' default value");
}

{
    my $compiler = Testgen::Runner::Compiler->new(
        compiler => 'gcc',
        c_flags  => ['-g'],
        ld_flags => ['-lgcc'],
    );
    can_ok($compiler, 'compile');

    my @cmd = $compiler->_create_cmd('a.c', 'a.out', '-O2');
    is_deeply(\@cmd,
              ['gcc', '-g', '-O2', 'a.c', '-o', 'a.out', '-lgcc'],
              'compile command');
}

done_testing;
