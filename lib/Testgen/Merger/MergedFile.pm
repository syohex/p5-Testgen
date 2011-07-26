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

    my $preprocessor_cmd = Testgen::Runner::Command->new(
        command => _preprocess_command($compiler, $file),
    );

    my ($status, $stdout, $stderr) = $preprocessor_cmd->run;

    my $prefix = _function_prefix($file);
    my $c_source = _remove_preprocessor_directives($stdout);
    push @{$self->{functions}}, _prepend_to_identifiers($c_source, $prefix);
    map { $self->{header}->{$_} = 1 } _find_lacking_headers($stderr, $compiler);

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

my $identifier_re = qr{ ([a-zA-Z_] (?: [a-zA-Z0-9_]+)? ) }xms;

## Based on $Regexp::Common::RE{num}{real}
my $real_num_re = qr{(?:(?i)(?:[+-]?)(?:(?=[.]?[0123456789])(?:[0123456789]*)(?:(?:[.])(?:[0123456789]{0,}))?)(?:(?:[E])(?:(?:[+-]?)(?:[0123456789]+))|))};

## Based on $Regexp::Common::RE{num}{int}
my $int_num_re = qr{(?:(?:[+-]?)(?:[0123456789ABCDEF]+))};

my $num_re = qr{
    (?: $real_num_re (?: d?f )? |  (?:0x)? $int_num_re (?:ul?l?|ll?)? )
}xmso;
###(?: 0[xX])? [0-9]+ (\. [0-9]+)? (?: (?i:ul?l?|ll?|e|l?f) )?

## Based on $Regexp::Common::RE{quoted}
my $quoted = qr{(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\")|(?:\')(?:[^\\\']*(?:\\.[^\\\']*)*)(?:\'))};

my $symbol_re = qr{ [\\+\-*&^~/%()\{\}\[\];=?|:><.!,] }xmso;

sub _prepend_to_identifiers {
    my ($file_str, $prefix) = @_;
    my $orig = $file_str;

    $file_str =~ s{ \s+ }{ }gxms;

    my %cache;
    while (1) {
        while ($orig =~ m{ \G (?:\s| $symbol_re+ | $quoted | $num_re) }gxmsc) {
            # read skip
        }

        if ($orig =~ m{\G $identifier_re }gxmsc) {
            my $identifier = $1;

            next if exists $ignore_word{$identifier};
            next if exists $cache{$identifier}; # already replaced

            unless ( exists $reserved_word{$identifier} ) {
                my $replace_str = "${prefix}_${identifier}";
                $file_str =~ s{$identifier}{$replace_str}g;

                $cache{$identifier} = 1;
            }

        } elsif ($orig =~ m{\G \z}gxmsc) {
            last;
        }
    }

    return $file_str;
}

sub _function_prefix {
    my $file = shift;

    $file =~ s{\.c$}{_}g;
    $file =~ s{\.}{_}g;
    $file =~ s{-}{_}g;

    return $file;
}

sub _preprocess_command {
    my ($compiler, $file) = @_;

    if ($compiler eq 'gcc') {
        return [ 'gcc', '-E', '-nostdinc', $file ];
    } else {
        Carp::croak("'$compiler' is not supported");
    }
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
    my $functions_str    = join "\n", @{$self->{functions}};

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
