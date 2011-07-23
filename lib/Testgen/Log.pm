package Testgen::Log;
use strict;
use warnings;

use Carp ();

use File::Spec ();
use File::Temp ();

binmode STDOUT, ":utf8";

my $tmpl = 'tmpXXXXXXX';

sub new {
    my ($class, %args) = @_;

    unless (defined $args{dir}) {
        Carp::croak("missing manfdatory 'dir' parameter");
    }

    my $fh = do {
        my $file_handle;
        if (exists $args{name}) {
            my $log = File::Spec->catfile($args{dir}, $args{name});
            open $file_handle, '>', $log or Carp::croak("Can't open $log: $!");
        } else {
            ($file_handle) = File::Temp::tempfile($tmpl, DIR => $args{dir});
        }
        $file_handle;
    };

    bless {
        fh  => $fh,
        %args,
    }, $class;
}

sub print {
    my ($self, $message) = @_;
    print {$self->{fh}} $message;
}

1;

__END__
