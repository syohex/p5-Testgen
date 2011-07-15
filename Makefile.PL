use inc::Module::Install;
use Module::Install::AuthorTests;

name 'Testgen';
all_from 'lib/Testgen.pm';

author_tests('xt');
WriteAll;
