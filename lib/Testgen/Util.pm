use strict;
use warnings;

package Testgen::Util;

use Carp ();

sub read_directory {
    my $dir = shift;

    opendir my $dh, $dir or Carp::croak("Can't open directory: $dir");
    my @dirs = grep { !m{^\.\.?$} } readdir $dh;
    closedir $dh;

    return @dirs;
}

sub count_ok_from_file {
    my $file = shift;

    my %regexp = (
        testinfo => qr{
            /\*\* \s* test \s* info \s* \*\*
        }xms,

        testinfo_ok => qr{ \b OK: \s*(\d+)\s* }xms,

        printok => qr{ \b printok \( \)   }xms,
    );

    my $str = do {
        local $/;
        open my $fh, '<', $file or Carp::croak("Can't open $file");
        <$fh>;
    };

    if ($str =~ m{ $regexp{testinfo} }xms) {
        if ($str =~ m{ $regexp{testinfo_ok} }xms) {
            return $1;
        } else {
            Carp::croak("Invalid 'test info' section");
        }
    }

    my $oknum = 0;
    $oknum += 1 while $str =~ m/ $regexp{printok} /gxms;
    return $oknum;
}

package
    Testgen::Util::Chdir;

use Cwd qw(getcwd);

sub new {
    my ($class, $dir) = @_;

    my $cwd = getcwd();
    my $guard = sub { chdir $cwd; };

    chdir($dir) or die "Can't chdir '$dir'";
    bless \$guard, $class;
}

sub DESTROY {
    ${$_[0]}->();
}

1;

__END__

=encoding utf8

=for stopwords

=head1 NAME

Testgen::Util - Utilities of Testgen

=head1 FUNCTIONS

=head2 C<< read_directory($directory) :Array >>

Read entries in C<$directory>

=head2 C<< count_ok_from_file($file) :Int >>

Read I<ok> which means passing test from C<$file> and returns ok number.

=head1 UTILITY CLASS

=head2 C<< Testgen::Util::Chdir >>

=cut
