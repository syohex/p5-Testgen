use strict;
use warnings;

use Test::More;

use Testgen::Parser;

{
    my $cparser = Testgen::Parser->create_parser(lang => 'c');
    ok($cparser);
    isa_ok($cparser, "Testgen::Parser");
    isa_ok($cparser, 'Testgen::Parser::CParser');
}

{
    my $cparser = Testgen::Parser->create_parser(lang => 'c');
    can_ok($cparser, 'prepend_to_identifier');

    my $str = <<'...';
 + - * & ^ / % ( ) { } [ ] ; = ? | : > < . ! ,

auto     _Bool      break       case
char     _Complex   const       continue
default  do         double      else
enum     extern     float       for
goto     if         _Imaginary  inline
int      long       register    restrict
return   short      signed      sizeof
static   struct     switch      typedef
union    unsigned   void        volatile
while

printf FLT_EPSILON

012345 9039382 0x4898489
1.4930 .9902390
+90.22 -944.44
29484.33dF 93939df 48485f

111ULL 222UL 333LL 444L 555U 666F 777Df
+19399 -19939

'quo\'ted' "double \" quoted"

a a1
_abc
foo
...

    my $expected =<<'...';
 + - * & ^ / % ( ) { } [ ] ; = ? | : > < . ! ,

auto     _Bool      break       case
char     _Complex   const       continue
default  do         double      else
enum     extern     float       for
goto     if         _Imaginary  inline
int      long       register    restrict
return   short      signed      sizeof
static   struct     switch      typedef
union    unsigned   void        volatile
while

printf FLT_EPSILON

012345 9039382 0x4898489
1.4930 .9902390
+90.22 -944.44
29484.33dF 93939df 48485f

111ULL 222UL 333LL 444L 555U 666F 777Df
+19399 -19939

'quo\'ted' "double \" quoted"

prefix_a prefix_a1
prefix__abc
prefix_foo
...

    my $ret = $cparser->prepend_to_identifier($str, 'prefix');

    is($ret, $expected, 'prepend identifier');
}

{
    my $cparser = Testgen::Parser->create_parser(lang => 'c');
    can_ok($cparser, 'find_missing_headers');

    my $str = <<'...';
no include path in which to search for stdio.h
       no include path in which search for not_match.h
...

    my @headers = $cparser->find_missing_headers($str);
    is_deeply(\@headers, [ 'stdio.h' ], 'extract headerfile');
}

{
    my $cparser = Testgen::Parser->create_parser(lang => 'c');
    can_ok($cparser, 'remove_preprocessor_directives');

    my $str = <<'...';
# AAA
# BBB
CCC
...
    my $ret = $cparser->remove_preprocessor_directives($str);
    is($ret, "CCC\n", "remove preprocessor's directive");
}

{
    eval {
        my $cparser = Testgen::Parser::CParser->new;
    };
    like $@, qr/Can't call constructor directly/, 'call constructor directory';
}

done_testing;
