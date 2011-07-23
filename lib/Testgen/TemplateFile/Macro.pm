package Testgen::TemplateFile::Macro;
use strict;
use warnings;

my @ignore_macros = ('$Id');

sub new {
    my ($class, %args) = @_;

    for my $key (qw/name dummy_args body/) {
        unless (exists $args{$key}) {
            Carp::croak("missing mandatory parameter '$key'");
        }
    }

    unless (ref $args{dummy_args} eq 'ARRAY') {
        Carp::croak("'parameters' must be ArrayRef");
    }

    bless { %args }, $class;
}

sub expand {
    my ($self, $real_args, $global_env) = @_;

    my $arg_length = scalar @{$real_args};

    unless (scalar @{$self->{dummy_args}} == $arg_length) {
        my $real_arg_str  = join ', ' , @{$real_args};
        my $real_arg_num  = scalar @{$real_args};

        my $dummy_args_str = join ',' , @{$self->{dummy_args}};
        my $dummy_args_num = scalar @{$self->{dummy_args}};

        Carp::croak(<<"...");
Arguments number does not equal to real argument
$self->{name}
   Dummy arguments($dummy_args_num): $dummy_args_str
   Real arguments($real_arg_num)   : $real_arg_str
...
    }

    my %arg_binding;
    for my $index (0..($arg_length - 1)) {
        $arg_binding{ ${$self->{dummy_args}}[$index] } = $real_args->[$index];
    }

    my ($body, $retval);
    $body = $retval = $self->{body};

    my $macro_regexp = qr{
        (   # $1 = macro_expression
            (\$[a-zA-Z0-9]+) # $2 = macro_name
            (?:
                \( ([^)]*) \) # $3 = macro args
            )?
        )
    }xms;

    my %cache;
    while ($body =~ m{ $macro_regexp }gxms) {
        my ($expression, $macro, $arg_str) = ($1, $2, $3);

        next if exists $cache{$expression}; # already expanded

        my $expanded;
        if (exists $arg_binding{$macro}) {
            $expanded = $arg_binding{$macro};
        } elsif ($global_env->{$macro}) {
            my $macro_def = $global_env->{$macro};
            my $arg_ref   = [ split ',', $arg_str ] || [];

            $expanded = $macro_def->expand($arg_ref, $global_env);
        } else {
            unless ( grep { $macro eq $_ } @ignore_macros ) {
                _macro_not_found($macro);
            }
            next;
        }

        my $quoted = quotemeta $expression;
        $retval =~ s{$quoted}{$expanded}g;
        $cache{$expression} = $expanded;
    }

    return $retval;
}

sub _macro_not_found {
    my $macro = shift;

    Carp::carp(<<"...");
$macro looks like a 'Macro', but its definition is not found.
...
}

1;
