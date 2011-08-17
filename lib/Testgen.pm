package Testgen;
use strict;

use 5.008_001;

our $VERSION = '0.02';

1;
__END__

=encoding utf8

=for stopwords

=head1 NAME

Testgen - Testsuite generator for C compilers

=head1 SYNOPSIS

  use Testgen;

=head1 DESCRIPTION

Testgen is testsuite generator for C compilers.
It genrates C source codes from template files and generates
script to run tests.

Testgen support merging tests. Testsuite has a lot of tests,
It takes too long time to compile and executeee them.
You can save time by merging tests.

=head1 AUTHOR

Authors of original source code are:

Yuki UCHIYAMA

Yuji NAGAMATSU

Kazushi MORIMOTO

Shinji OBUCHI

Nagisa ISHIURA

Nobuyuki HIKICHI

=head1 CODE REFACTORING

Syohei YOSHIDA E<lt>syohex@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2011- Ishiura Lab. in Kwansei Gakuin University, SRA-KTL, SRA

=head1 LICENSE

Programs that use this code are bound to the terms and conditions of
the GNU GPL (see the LICENSE file)

=head1 SEE ALSO

L<http://ist.ksc.kwansei.ac.jp/~ishiura/pub/testgen/>

=cut
