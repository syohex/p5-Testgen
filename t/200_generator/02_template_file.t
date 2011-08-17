use strict;
use warnings;

use File::Spec;
use File::Temp;
use File::Path;

use Test::More;
use Testgen::TemplateFile;

use t::Util qw/create_tmp_file/;

{
    my $content = <<'...';
this is template
...
    my $template = create_tmp_file(
        content => $content,
        suffix  => '.tt',
    );

    my $tt_file = Testgen::TemplateFile->new(
        name => $template->filename,
        testsuite_dir => 'test',
    );
    ok($tt_file, 'constructor');
    isa_ok($tt_file, 'Testgen::TemplateFile');

    is($tt_file->{name}, $template->filename, "'file' param");
    is($tt_file->{testsuite_dir}, 'test', "'testsuite_dir' param");

    is_deeply($tt_file->{macros}, {}, "default 'macros' param");
    is($tt_file->{filename_index}, 0, "default 'filename_index' param");
    is($tt_file->{template_encoding}, 'utf8', "default 'template_encoding' param");
    is($tt_file->{output_encoding}, 'utf8', "default 'output_encoding' param");

    can_ok($tt_file, 'parse');

    my $retval = $tt_file->_decide_filename('test.c');
    is($retval,  'test.c', 'name has no placeholder');

    $retval = $tt_file->_decide_filename('test????.c');
    is($retval, 'test0000.c', 'decide');
}

{
    my $content = <<'...';
@def $TEST($ARG)
This is $ARG
@def_

@comment
Ignore this section
@comment_
...

    my $template = create_tmp_file(
        content => $content,
        suffix  => '.tt',
    );


    my $tt_file = Testgen::TemplateFile->new(
        name => $template->filename,
        testsuite_dir => 'test',
    );
    $tt_file->parse();

    my $macro = $tt_file->{macros}->{'$TEST'};
    isa_ok($macro, 'Testgen::TemplateFile::Macro');

    is($macro->{name}, '$TEST', 'macro name');
    is_deeply($macro->{dummy_args}, ['$ARG'], 'macro dummy args');
    is($macro->{body}, "This is \$ARG\n", 'macro body');
}

{
    my $content = <<'...';
@def $TEST($ARG)
This is $ARG
@def_
...

    my $include_file = create_tmp_file(
        content => $content,
        suffix  => '.inc',
    );
    $include_file->autoflush(1);

    my $filename = $include_file->filename;
    my $content2 = <<"...";
\@include
$filename
\@include_
...

    my $template = create_tmp_file(
        content => $content2,
        suffix  => '.tt',
    );

    my $tt_file = Testgen::TemplateFile->new(
        name => $template->filename,
        testsuite_dir => 'test',
    );
    $tt_file->parse();

    my $macro = $tt_file->{macros}->{'$TEST'};

    is($macro->{name}, '$TEST', 'included macro name');
    is_deeply($macro->{dummy_args}, ['$ARG'], 'included macro dummy args');
    is($macro->{body}, "This is \$ARG\n", 'included macro body');
}

{
    my $tempdir  = File::Temp::tempdir( CLEANUP => 1 );
    my $content = <<'...';
@def $test($ARG)
This is $ARG
@def_

@dir testtest
@file >>t???.c $test([,arg1]) @ok 5 @ok_ @file_
@comment
This is comment
@comment_
@dir_
...
    my $template = create_tmp_file(
        content => $content,
        suffix  => '.tt',
    );

    my $tt_file = Testgen::TemplateFile->new(
        name => $template->filename,
        testsuite_dir => $tempdir,
    );
    $tt_file->parse();

    my $testdir = File::Spec->catfile($tempdir, 'testtest');
    ok(-d $testdir, 'create directory');

    my $t000 = do {
        local $/;
        my $file = File::Spec->catfile($testdir, 't000.c');
        open my $fh, '<', $file or die "Can't open $file: $!";
        <$fh>;
    };
    is("This is \n", $t000, "generate file with arg(empty)");

    my $t001 = do {
        local $/;
        my $file = File::Spec->catfile($testdir, 't001.c');
        open my $fh, '<', $file or die "Can't open $file:$!";
        <$fh>;
    };
    is("This is arg1\n", $t001, "generate file with arg(not empty)");

    my $fileset = do {
        local $/;
        my $file = File::Spec->catfile($testdir, 'FILESET');
        open my $fh, '<', $file or die "Can't open $file:$!";
        <$fh>;
    };
    is("t000.c: 5\nt001.c: 5\n", $fileset, "fileset content");
}

{
    my $content = <<'...';
@unknown
This is unknown section
@unknown_
...
    my $template = create_tmp_file(
        content => $content,
        suffix  => '.tt',
    );

    my $tt_file = Testgen::TemplateFile->new(
        name => $template->filename,
        testsuite_dir => 'test',
    );

    eval {
        $tt_file->parse;
    };
    like $@, qr/Unknown section/, 'parsing unknown section';
}

{
    eval {
        my $tt_file = Testgen::TemplateFile->new(
            testsuite_dir => 'test',
        );
    };
    like $@, qr/missing mandatory parameter 'name'/, 'no name';

    eval {
        my $tt_file = Testgen::TemplateFile->new(
            name => 'test.tt',
        );
    };
    like $@, qr/missing mandatory parameter 'testsuite_dir'/, 'no directory';
}

{
    my $tt_file = Testgen::TemplateFile->new(
        name => 'NOTFOUND',
        testsuite_dir => 'test',
    );

    eval {
        $tt_file->parse;
    };
    like $@, qr/Can't open/, 'template file not found';
}

{
    my $str = '$macro10([,static,register],[int,unsigned,short,char])';
    my ($name, $arg_ref) = Testgen::TemplateFile::_parse_macro_str($str);

    is($name, '$macro10', 'exploit macro name');

    my $expected = [
        [ '', 'static', 'register'],
        [ 'int', 'unsigned', 'short', 'char'],
    ];
    is_deeply($arg_ref, $expected, 'exploit macro args');
}

done_testing;
