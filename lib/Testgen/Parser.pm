package Testgen::Parser;
use strict;
use warnings;

use Carp ();

sub create_parser {
    my ($class, %args) = @_;

    unless (exists $args{lang}) {
        Carp::croak("missing mandatory parameter 'lang'");
    }

    my $lang = ucfirst( lc(delete $args{lang}) );
    my $parser_class = __PACKAGE__ . "::" . "${lang}Parser";

    my $parser;
    if ( _load_class($parser_class) ) {
        $parser = $parser_class->new(%args);
    } else {
        Carp::croak("'$lang' parser is not implemented yet");
    }

    return $parser;
}

sub _load_class {
    my $class_name = shift;

    $class_name =~ s{::}{/}g;
    $class_name .= '.pm';

    eval {
        require $class_name;
    };

    return 0 if $@;

    return 1;
}

sub prepend_to_identifier {
    die "prepend_to_identifiers must be overridden";
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Parser - A base class of parser of each language.

=cut
