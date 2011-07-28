package Testgen::Parser;
use strict;
use warnings;

use Carp ();

sub create_parser {
    my ($class, %args) = @_;

    unless (exists $args{lang}) {
        Carp::croak("missing mandatory parameter 'lang'");
    }

    my $lang = delete $args{lang};
    $lang = lc $lang;

    my $parser;
    if ($lang eq 'c') {
        require Testgen::Parser::CParser;
        $parser = Testgen::Parser::CParser->new(%args);
    } else {
        Carp::croak("'$lang' parser is not implemented yet");
    }

    return $parser;
}

sub prepend_to_identifier {
    die "prepend_to_identifiers should be overridden";
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Parser - A base class of parser of each language.

=cut
