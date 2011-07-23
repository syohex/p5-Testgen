use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Testgen';
all_from 'lib/Testgen.pm';

test_requires 'Test::More' => 0.88; # done_testing

tests 't/*.t t/*/*.t';
author_tests('xt');

WriteAll;
