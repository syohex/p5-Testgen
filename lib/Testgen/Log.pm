package Testgen::Log;
use strict;
use warnings;

use Carp ();
use Encode ();
use File::Spec ();
use File::Temp ();

my $TMPL = 'tmpXXXXXXX';

sub new {
    my ($class, %args) = @_;

    unless (defined $args{dir}) {
        Carp::croak("missing manfdatory 'dir' parameter");
    }

    my $encoding = delete $args{encoding} || 'utf8';
    my $encoder  = Encode::find_encoding($encoding);
    unless (defined $encoder) {
        Carp::croak("Not found encoding '$encoding'");
    }

    my $fh = do {
        my $file_handle;
        if (exists $args{name}) {
            my $log = File::Spec->catfile($args{dir}, $args{name});
            open $file_handle, '>', $log or Carp::croak("Can't open $log: $!");
        } else {
            ($file_handle) = File::Temp::tempfile($TMPL, DIR => $args{dir});
        }
        $file_handle;
    };

    bless {
        fh      => $fh,
        encoder => $encoder,
        %args,
    }, $class;
}

sub print {
    my ($self, $message) = @_;
    print {$self->{fh}} $self->{encoder}->encode($message);
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Log - A Testgen log class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Log->new(%args) :Testgen::Log >>

I<%args> might be:

=over

=item dir :Str

The Directory where log is created.
This is a B<mandatory parameter>.

=item name :Str

Log name. If name is not specified, a log is created by
C<File::Temp::tempfile>.

=item encoding :Str = "utf8"

Output encoding.

=back

=head2 Instance Methods

=head3 C<< $log->print($string) >>

Print out I<$string> encoded C<$self->{encoding}> to stdout.
I<$string> should be as I<string>, not octet stream.

=cut
