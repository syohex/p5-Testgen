use strict;
use warnings;

use Test::More;
use Testgen::TemplateFile::Macro;

{
    my $macro = Testgen::TemplateFile::Macro->new(
        name => 'test',
        dummy_args => [ qw/$VAR1 $VAR2/ ],
        body => "This is macro",
    );
    ok($macro, 'constructor');
    isa_ok($macro, 'Testgen::TemplateFile::Macro');

    is($macro->{name}, 'test', 'name parameter');
    is_deeply($macro->{dummy_args}, [qw/$VAR1 $VAR2/], 'dummy_args parameter');
    is($macro->{body}, 'This is macro', 'body parameter');
}

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

{
    my $test_body =<<'...';
$VAR9
$PRINT("%s\n","@OK@");
$WRITE("@OK@");
...

    my $macro = Testgen::TemplateFile::Macro->new(
        name => '$PRINT',
        dummy_args => [ qw/$VAR9/ ],
        body => $test_body,
    );

    ok($macro, 'constucter. body param is CodeRef');

    my $expected =<<'...';
TEST
printf("%s\n","@OK@");
write(1, "@OK@", 4);
...

    my $builtin = {
        '$PRINT' => Testgen::TemplateFile::Macro->new(
            name => '$PRINT',
            body => sub {
                "printf($_)";
            },
        ),

        '$WRITE' => Testgen::TemplateFile::Macro->new(
            name => '$WRITE',
            body => sub {
                my $string = shift;
                my $length;
                if ($string =~ m{^"([^"]+)"$}) {
                    $length = length $1;
                } else {
                    $length = length $string;
                }

                my $stdout_fd = 1;
                "write($stdout_fd, $string, $length)";
            },
        ),
    };

    is($macro->expand(['TEST'], $builtin), $expected,
       'macro expand with builtin func');
}

done_testing;
