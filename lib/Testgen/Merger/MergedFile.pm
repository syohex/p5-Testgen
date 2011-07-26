package Testgen::Merger::MergedFile;
use strict;
use warnings;

use Carp ();

use Testgen::Runner::Command;

sub new {
    my ($class, %args) = @_;

    unless (exists $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    bless {
        functions    => [],
        header       => {},
        pseudo_mains => [],
        %args,
    }, $class;
}

sub add {
    my ($self, $file) = @_;
    my $compiler = $self->{compiler};

    my ($preprocessed, $stderr) = $self->{compiler}->preprocess($file);

    my $prefix = _function_prefix($file);
    my $c_source = _remove_preprocessor_directives($preprocessed);
    push @{$self->{functions}}, _prepend_to_identifiers($c_source, $prefix);
    map { $self->{header}->{$_} = 1 } _find_lacking_headers($stderr, $compiler->name);

    push @{$self->{pseudo_mains}}, "${prefix}_main";
}

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
my $real_num_re = qr{(?:(?i)(?:[+-]?)(?:(?=[.]?[0-9])(?:[0-9]*)(?:(?:[.])(?:[0-9]{0,}))?)(?:(?:[eE])(?:(?:[+-]?)(?:[0-9]+))))};

## Based on $Regexp::Common::RE{num}{int}
my $octal_re   = qr{(?:(?:[+-]?)(?:[0-7]+))};
my $decimal_re = qr{(?:(?:[+-]?)(?:[0-9]+))};
my $hex_re     = qr{(?:(?:[+-]?)0[xX](?:[0-9a-fA-F]+))};
my $int_re = qr{ (?: $hex_re | $octal_re | $decimal_re ) (?: (?i)(?:ul?l?|ll?|d?f) )? }x;

my $num_re = qr{ (?: $real_num_re (?: (?i)(?:d?f) )? | $int_re ) }xmso;

## Based on $Regexp::Common::RE{quoted}
my $quoted = qr{(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\")|(?:\')(?:[^\\\']*(?:\\.[^\\\']*)*)(?:\'))};

my $symbol_re = qr{ [\\+\-*&^~/%()\{\}\[\];=?|:><.!,] }xmso;

sub _prepend_to_identifiers {
    my ($file_str, $prefix) = @_;
    my $orig = $file_str;
    my $replaced = '';

    $file_str =~ s{ \s+ }{ }gxms;

    my %cache;
    while (1) {
        while ($orig =~ m{ \G ( \s| $symbol_re+ | $quoted | $num_re ) }gxmsc) {
            $replaced .= $1;
            # read skip
        }

        if ($orig =~ m{\G ( $identifier_re ) }gxmsc) {
            my $identifier = $1;

            if (exists $reserved_word{$identifier}
                || exists $ignore_word{$identifier}) {
                $replaced .= $identifier;
            } else {
                $replaced .= "${prefix}_${identifier}";
            }

        } elsif ($orig =~ m{\G \z}gxmsc) {
            last;
        }
    }

    return $replaced;
}

sub _function_prefix {
    my $file = shift;

    $file =~ s{\.c$}{_}g;
    $file =~ s{\.}{_}g;
    $file =~ s{-}{_}g;

    return $file;
}

sub _remove_preprocessor_directives {
    my $str = shift;
    $str =~ s{ ^ \# .*? $ }{}gxms;
    return $str;
}

sub output_as_main_file {
    my ($self, $file) = @_;

    my $headers_str     = join "\n", keys %{$self->{headers}};
    my $pseudo_main_str = join "\n", map { "$_();" } @{$self->{pseudo_mains}};
    my $functions_str    = join "\n", @{$self->{functions}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
#ifdef unix
#include <stdio.h>
#endif
$headers_str

int main ()
{

$pseudo_main_str

    return 0;
}

$functions_str
...

    close $fh;
}

sub output_as_sub_file {
    my ($self, $file) = @_;

    my $headers_str     = join "\n", keys %{$self->{headers}};
    my $pseudo_main_str = join ";\n", @{$self->{pseudo_mains}};
    my $functions_str   = join "\n", @{$self->{functions}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
#ifdef unix
#include <stdio.h>
#endif
$headers_str

$functions_str
...
    close $fh;
}

my %error_message = (
    gcc => qr{
        no \s+ include \s+ path \s+ in \s+ which \s+ to \s+ search \s+ for \s+
        ([^.]+.h)
    }ixmso,
);

sub _find_lacking_headers {
    my ($str, $compiler) = @_;

    my %header;
    my $regexp = $error_message{$compiler};
    while ($str =~ m{$regexp}g) {
         $header{$1} = 1;
    }

    return keys %header;
}

1;

__END__
