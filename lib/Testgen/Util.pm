use strict;
use warnings;

package Testgen::Util;

use Carp ();
use File::Path ();

sub make_dir {
    my $dir = shift;

    File::Path::rmtree([$dir], 0, 0) if -d $dir;
    File::Path::mkpath([$dir], 0, 0777);
}

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

        testinfo_ok => qr{ \bOK: \s*(\d+)\s* }xms,

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

=encoding utf-8

=for stopwords

=head1 NAME

Testgen::Util - Utilities of Testgen

=cut
