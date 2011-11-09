use strict;
use Test::More;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;

my $spell_cmd;
foreach my $path (split(/:/, $ENV{PATH})) {
    -x "$path/spell"  and $spell_cmd="spell", last;
    -x "$path/ispell" and $spell_cmd="ispell -l", last;
    -x "$path/aspell" and $spell_cmd="aspell list", last;
}
plan skip_all => "no spell/ispell/aspell" unless $spell_cmd;

set_spell_cmd($spell_cmd);

add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
use strict;
use Test::More;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;

my $spell_cmd;
foreach my $path (split(/:/, $ENV{PATH})) {
    -x "$path/spell"  and $spell_cmd="spell", last;
    -x "$path/ispell" and $spell_cmd="ispell -l", last;
    -x "$path/aspell" and $spell_cmd="aspell list", last;
}
plan skip_all => "no spell/ispell/aspell" unless $spell_cmd;

set_spell_cmd($spell_cmd);

add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');

__DATA__
Syohei YOSHIDA
syohex
GPL
Gakuin
HIKICHI
ISHIURA
Ishiura
KTL
Kazushi
Kwansei
MORIMOTO
NAGAMATSU
Nagisa
Nobuyuki
OBUCHI
SRA
Shinji
Testgen
Testsuite
UCHIYAMA
Yuji
Yuki
genrates
testsuite
lang
TODO
FAQ
Testgen
utf
Balazs
Szabo
dLux
Str
stdout
stderr
oknum
printok
cnf
runtest
dir
ok
