package Testgen::TemplateFile::Macro;
use strict;
use warnings;

my @ignore_macros = ('$Id');

sub new {
    my ($class, %args) = @_;

    for my $key (qw/name body/) {
        unless (exists $args{$key}) {
            Carp::croak("missing mandatory parameter '$key'");
        }
    }

    my $dummy_args = delete $args{dummy_args} || [];
    unless (ref $dummy_args eq 'ARRAY') {
        Carp::croak("'parameters' must be ArrayRef");
    }

    bless {
        dummy_args => $dummy_args,
        %args,
    }, $class;
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
        } elsif (exists $global_env->{$macro}) {
            my $macro_def = $global_env->{$macro};

            if (ref $macro_def->{body} eq 'CODE') {
                my @args = split /[,\s]/, $arg_str;
                local $_ = $arg_str;
                $expanded = $macro_def->{body}->(@args);
            } else {
                my $arg_ref = [ split /[,\s]/, $arg_str ];
                $expanded = $macro_def->expand($arg_ref, $global_env);
            }
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

__END__

=encoding utf8

=head1 NAME

Testgen::TemplateFile::Macro - Macro class in template file

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::TemplateFile::Macro->new(%args) :Testgen::TemplateFile::Macro >>

Creates and returns a new Testgen::TemplateFile::Macro object with I<args>.
Dies on error.

I<%args> might be:

=over

=item name :Str

=item dummy_args :ArrayRef[Str] = []

=item body : Str or CodeRef

=back

=head2 Instance Methods

=head3 C<< $macro->expand($real_args, $global_env) >>

Expand macro. I<real_args> binds to C<$macro->{dummy_args}>.

=cut
