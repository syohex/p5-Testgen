use strict;
use warnings;

use Test::More;
use Testgen::TemplateFile::Macro;

{
    my $test_body =<<'...';
    itest = NO;
    $VAR9 = OK;
    itest = $VAR9;

    if (itest == OK)
        printok();
    else
        printno();
...

    my $macro = Testgen::TemplateFile::Macro->new(
        name => 'test',
        dummy_args => [ qw/$VAR9/ ],
        body => $test_body,
    );

    ok($macro, 'constucter');

    my $expected =<<'...';
    itest = NO;
    TEST = OK;
    itest = TEST;

    if (itest == OK)
        printok();
    else
        printno();
...

    can_ok($macro, 'expand');

    is($macro->expand(['TEST'], {}), $expected, 'macro expand no global');
}

done_testing;
