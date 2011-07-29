package Testgen::Parser::CParser;
use strict;
use warnings;

use base qw/Testgen::Parser/;
use Carp ();

sub new {
    my ($class, %args) = @_;

    my $caller = (caller)[0];
    unless ($caller eq 'Testgen::Parser') {
        Carp::croak("Can't call constructor directly");
    }

    unless (exists $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    bless { %args }, $class;
}

## Reserved words of C99
my @RESERVED = (qw/
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
/);
my %reserved_word = map { $_ => 1 } @RESERVED;

my @IGNORES = qw/ printf FLT_EPSILON /;
my %ignore_word  = map { $_ => 1 } @IGNORES;

my $identifier_re = qr{ [a-zA-Z_] (?: [a-zA-Z0-9_]+)? }xms;

## Based on $Regexp::Common::RE{num}{real}
my $real_num_re = qr{(?:[+-]?(?:(?=[.]?[0-9])(?:[0-9]*)(?:(?:[.])(?:[0-9]{0,}))?)(?:(?:[eE])(?:(?:[+-]?)(?:[0-9]+))|))}o;

## Based on $Regexp::Common::RE{num}{int}
my $octal_re   = qr{0[0-7]+}ox;
my $decimal_re = qr{(?:[0-9]|[1-9][0-9]+)}ox;
my $hex_re     = qr{0[xX][0-9a-fA-F]+}ox;
my $int_re = qr{[+-]?(?:$octal_re|$hex_re|$decimal_re)(?:ull|ul|ll|[ul]|df|f)?}iox;

my $num_re = qr{(?:$int_re|$real_num_re(?:d?f)?) }iox;

## Based on $Regexp::Common::RE{quoted}
my $quoted = qr{(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\")|(?:\')(?:[^\\\']*(?:\\.[^\\\']*)*)(?:\'))}o;

my $symbol_re = qr{ [\\+\-\*&^~/%()\{\}\[\];=?|:><.!,] }oxms;

sub prepend_to_identifier {
    my ($self, $file_str, $prefix) = @_;
    my $replaced = '';

    my @tokens;
    while (1) {
        if ($file_str =~ m{\G (\s+) }gcxms ) {
            push @tokens, $1;
        } elsif ($file_str =~ m{\G ($quoted) }gcxms ) {
            push @tokens, $1;
        } elsif ($file_str =~ m{\G ($num_re) }gcxms) {
            push @tokens, $1;
        } elsif ($file_str =~ m{\G ( (?:$symbol_re)+ ) }gcxms) {
            push @tokens, $1;
        } elsif ($file_str =~ m{\G ( $identifier_re ) }gcxms) {
            my $identifier = $1;
            if (exists $reserved_word{$identifier}
                || exists $ignore_word{$identifier}) {
                push @tokens, $identifier;
            } else {
                push @tokens, "${prefix}_${identifier}"
            }

        } elsif ($file_str =~ m{\G \z}gcxms) {
            last;
        } else {
            Carp::croak("Oops, found token which is not match all regexp");
        }
    }

    return join '', @tokens;
}

my %error_message = (
    gcc => qr{
        no \s+ include \s path \s in \s which \s to \s search \s for \s
        ([^.]+\.h)
    }ixmso,

    clang => qr{
        ' ([^']+) ' \s file \s not \s found
    }ixmso,

    pcc => qr{
       error: \s cannot \s find \s '([^']+)'
    }ixmso,
);

sub find_missing_headers {
    my ($self, $errmsg) = @_;

    my $compiler = $self->{compiler};
    unless (exists $error_message{$compiler}) {
        Carp::croak("'$compiler' is not supported\n");
    }

    my $regexp = $error_message{$compiler};
    my %header;
    while ($errmsg =~ m{$regexp}g) {
         $header{$1} = 1;
    }

    return keys %header;
}

sub remove_preprocessor_directives {
    my ($self, $str) = @_;
    $str =~ s{ ^ \# .*? $ }{}gxms;
    return $str;
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Parser::CParser - A C language parser class

=head1 INTERFACE

=head2 Constructor

You cannot call constructor of C<Testgen::Parser::CParser> directly.
You can get C<Testgen::Parser::CParser> instance via
C<Testgen::Parser::create_parser>

=head2 Instance Methods

=head3 C<< $runner->add($file, $prefix)  >>

Add a C<$file> to merged files. C<$prefix> has a meaning
case of separate compilation.

=head3 C<< $runner->output_as_main_file >>

Generate file which contains 'main' function.

=head3 C<< $runner->output_as_sub_file >>

Generate file which does not contain 'main' function.

=cut
