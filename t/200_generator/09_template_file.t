use strict;
use warnings;

use Test::More;
use Testgen::TemplateFile;

{
    # private method
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
