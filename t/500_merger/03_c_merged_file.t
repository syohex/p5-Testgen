use strict;
use warnings;

use Test::More;

use Testgen::Merger::MergedFile;
use Testgen::Runner::Compiler;

use t::Util qw/create_tmp_file/;

{
    my $compiler = Testgen::Runner::Compiler->new(
        name     => 'gcc',
        c_flags  => ['-g', '-Dlinux'],
        ld_flags => ['-lm']
    );

    my $merged_file = Testgen::Merger::MergedFile->create_mergedfile(
        lang => 'c',
        compiler => $compiler,
    );
    ok($merged_file);
    isa_ok($merged_file, "Testgen::Merger::MergedFile::CMergedFile");

    can_ok($merged_file, 'add');
    can_ok($merged_file, 'output_as_main_file');
    can_ok($merged_file, 'output_as_sub_file');
}

{
    my $file1_str = <<'...';
#include <stdio.h>

int main (void)
{
    return 10;
}
...

    my $file1 = create_tmp_file(
        content => $file1_str,
        suffix  => '.c',
    );

    my $file2_str = <<'...';
#include <float.h>
int main (void)
{
    return 1 + 1;
}
...

    my $file2 = create_tmp_file(
        content => $file2_str,
        suffix  => '.c',
    );

    my $compiler = Testgen::Runner::Compiler->new(
        name     => 'gcc',
        c_flags  => ['-g', '-Dlinux'],
        ld_flags => ['-lm']
    );

    my $merged_file = Testgen::Merger::MergedFile->create_mergedfile(
        lang => 'c',
        compiler => $compiler,
    );

    $merged_file->add($file1->filename, 'test1');
    $merged_file->add($file2->filename, 'test2');

    my $main = $merged_file->output_as_main_file;
    like $main, qr/ ^ int \s+ main \s+ \(\)/xms, 'has main';
    like $main, qr/test1_main/xms, 'has test1_main';
    like $main, qr/test2_main/xms, 'has test2_main';
    like $main, qr/ \# include <stdio \. h>/xms, 'has headerfile stdio';
    like $main, qr/ \# include <float \. h>/xms, 'has headerfile float';

    my $sub = $merged_file->output_as_sub_file;
    ok( $sub !~ m{^ int \s+ main \s+ \(\) }xms, 'not have main');
    like $sub, qr/test1_main/xms, 'has test1_main in sub';
    like $sub, qr/test2_main/xms, 'has test2_main in sub';
    like $sub, qr/ \# include <stdio \. h>/xms, 'has headerfile stdio in sub';
    like $sub, qr/ \# include <float \. h>/xms, 'has headerfile float in sub';


}

done_testing;

