package Testgen::Parser::CParser;
use strict;
use warnings;

use base qw/Testgen::Parser/;
use Carp ();

sub new {
    my ($class, %args) = @_;

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

my @IGNORES = qw/ printf /;
my %ignore_word  = map { $_ => 1 } @IGNORES;

my $identifier_re = qr{ [a-zA-Z_] (?: [a-zA-Z0-9_]+)? }xms;

## Based on $Regexp::Common::RE{num}{real}
my $real_num_re = qr{(?:(?i)(?:[+-]?)(?:(?=[.]?[0-9])(?:[0-9]*)(?:(?:[.])(?:[0-9]{0,}))?)(?:(?:[eE])(?:(?:[+-]?)(?:[0-9]+))|))};

## Based on $Regexp::Common::RE{num}{int}
my $octal_re   = qr{(?:(?:[+-]?)(?:[0-7]+))};
my $decimal_re = qr{(?:(?:[+-]?)(?:[1-9](?: [0-9]+) ?))};
my $hex_re     = qr{(?:(?:[+-]?)0[xX](?:[0-9a-fA-F]+))};
my $int_re = qr{ (?: $hex_re | $octal_re | $decimal_re ) (?: (?i)(?:ul?l?|ll?|d?f) )? }x;

my $num_re = qr{ (?: $int_re | $real_num_re (?: (?i)(?:d?f) )? ) }xmso;

## Based on $Regexp::Common::RE{quoted}
my $quoted = qr{(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\")|(?:\')(?:[^\\\']*(?:\\.[^\\\']*)*)(?:\'))};

my $symbol_re = qr{ [\\+\-\*&^~/%()\{\}\[\];=?|:><.!,] }xmso;

sub prepend_to_identifier {
    my ($self, $file_str, $prefix) = @_;
    my $replaced = '';

    $file_str =~ s{ \s+ }{ }gxms;

    my %cache;
    while (1) {
        while ($file_str =~ m{ \G (\s|$quoted|$num_re|$symbol_re+) }gxmsc) {
            $replaced .= $1;
        }

        if ($file_str =~ m{\G ( $identifier_re ) }gxmsc) {
            my $identifier = $1;

            if (exists $reserved_word{$identifier}
                || exists $ignore_word{$identifier}) {
                $replaced .= $identifier;
            } else {
                $replaced .= "${prefix}_${identifier}";
            }

        } elsif ($file_str =~ m{\G \z}gxmsc) {
            last;
        }
    }

    return $replaced;
}

my %error_message = (
    gcc => qr{
        no \s+ include \s path \s in \s which \s to \s search \s for \s
        ([^.]+.h)
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
    my $str = shift;
    $str =~ s{ ^ \# .*? $ }{}gxms;
    return $str;
}

1;

__END__
