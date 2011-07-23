#!perl
use strict;
use warnings;

use lib qw(lib);

use Testgen::Generator;

my $generator = Testgen::Generator->new();
$generator->parse_options(@ARGV);
$generator->run;
