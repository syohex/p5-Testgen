package Testgen::Parser;
use strict;
use warnings;

use Carp ();
use Testgen::Util ();

sub create_parser {
    my ($class, %args) = @_;

    unless (exists $args{lang}) {
        Carp::croak("missing mandatory parameter 'lang'");
    }

    my $lang = ucfirst( lc(delete $args{lang}) );
    my $parser_class = __PACKAGE__ . "::" . "${lang}Parser";

    my $parser;
    if ( Testgen::Util::load_class($parser_class) ) {
        $parser = $parser_class->new(%args);
    } else {
        Carp::croak("'$lang' parser is not implemented yet");
    }

    return $parser;
}

sub prepend_to_identifier {
    die "prepend_to_identifiers must be overridden";
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Parser - Base class of parser of each language.

=cut
