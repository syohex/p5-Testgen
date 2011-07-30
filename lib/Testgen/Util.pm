use strict;
use warnings;

package Testgen::Util;

use Carp ();

sub read_directory {
    my $dir = shift;

    opendir my $dh, $dir or Carp::croak("Can't open directory $dir: $!");
    my @dirs = grep { !m{^\.\.?$} } readdir $dh;
    closedir $dh;

    return @dirs;
}

# Based on http://ja.doukaku.org/44/lang/perl/
sub combination {
    my ($a1, $a2) = splice @_, 0, 2;
    my @result;
    for my $e1 (@{$a1}) {
        for my $e2 (@{$a2}) {
            push @result, [ (ref $e1 ? @{$e1} : $e1), $e2 ];
        }
    }
    @_ ? combination([ @result ], @_) : [ @result ];
}

# 'which' function is based on 'File::Which::which'.
sub which {
    my $command = shift;
    my @paths = File::Spec->path;
    my @extensions = ('');

    if ($^O eq 'MSWin32') {
        unshift @paths, '.';
        push @extensions, '.exe';
    }

    for my $path ( @paths ) {
        my $path = File::Spec->catfile($path, $command);

        for my $extension (@extensions) {
            my $file = $path . $extension;
            next if -d $file;

            if (-e $file && -x $file) {
                return 1;
            }
        }
    }

    return 0;
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

=head1 UTILITY CLASS

=head2 C<< Testgen::Util::Chdir >>

=cut
