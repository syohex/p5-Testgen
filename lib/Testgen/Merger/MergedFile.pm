package Testgen::Merger::MergedFile;
use strict;
use warnings;

use Carp ();

use Testgen::Runner::Command;
use Testgen::Parser;
use Testgen::Util ();

sub create_mergedfile {
    my ($class, %args) = @_;

    unless (exists $args{lang}) {
        Carp::croak("missing mandatory parameter 'lang'");
    }

    my $lang = ucfirst( lc(delete $args{lang}) );
    my $merged_file_class = __PACKAGE__ . "::" . "${lang}MergedFile";

    my $merged_file;
    if ( Testgen::Util::load_class($merged_file_class) ) {
        $merged_file = $merged_file_class->new(%args);
    } else {
        Carp::croak("To merge '$lang' files is not implemented yet");
    }

    return $merged_file;
}

sub add {
    die "You must override 'add' method";
}

sub output_as_main_file {
    die "You must override 'output_as_main_file' method";
}

sub output_as_sub_file {
    die "You must override 'output_as_sub_file' method";
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Merger::MergedFile - Base class of Merged file.

=head1 INTERFACE

=head2 Overridden Methods by Child Class

=head3 add

=head3 output_as_main_file

=head3 output_as_sub_file

=cut
