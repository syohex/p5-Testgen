use strict;
use warnings;

package Testgen::Util;

use Carp ();
use POSIX ();

sub read_directory {
    my $dir = shift;

    opendir my $dh, $dir or Carp::croak("Can't open directory $dir: $!");
    my @dirs = grep { !m{^\.\.?$} } readdir $dh;
    closedir $dh;

    return @dirs;
}

my %type_postfix = (
    'long'        => 'L',
    'long long'   => 'LL',
    'float'       => 'F',
    'long double' => 'L',
);

sub get_type_limit {
    use bignum; ## for very large number

    my %args = @_;

    for my $param (qw/type bit_width/) {
        unless (exists $args{$param}) {
            Carp::croak("missing '$param' parameter");
        }
    }

    my $complement = delete $args{complement} || 2;
    unless ($complement == 1 || $complement == 2) {
        Carp::croak("'complement' parameter should be '1' or '2'");
    }
    my $type_name   = delete $args{type};
    my $bit_width   = delete $args{bit_width};
    my $is_unsigned = delete $args{unsigned} || 0;
    my $suffix      = delete $args{suffix} || 0;

    my ($min, $max);
    if ($type_name eq 'float') {
        $min = POSIX::FLT_MIN;
        $max = POSIX::FLT_MAX;
    } elsif ($type_name eq 'double') {
        $min = POSIX::DBL_MIN;
        $max = POSIX::DBL_MAX;
    } elsif ($type_name eq 'long double') {
        $min = POSIX::LDBL_MIN;
        $max = POSIX::LDBL_MAX;
    } else {
        if ($is_unsigned) {
            $min = 0;
            $max = (2 ** $bit_width) - 1;
        } else {
            $min = -(2 ** ($bit_width-1));
            $max = (2 ** ($bit_width-1)) - 1;

            $min += 1 if $complement == 1;
        }
    }

    if ($suffix) {
        if ($is_unsigned) {
            $min .= "U";
            $max .= "U";
        }

        if (exists $type_postfix{$type_name}) {
            $min .= $type_postfix{$type_name};
            $max .= $type_postfix{$type_name};
        }
    }

    return ($min, $max);
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

sub load_class {
    my $class_name = shift;

    $class_name =~ s{::}{/}g;
    $class_name .= '.pm';

    eval {
        require $class_name;
    };

    return 0 if $@;

    return 1;
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

=head2 C<< conbination($array_ref1, $array_ref2 ...) :Array >>

Get all combination.

=head2 C<< which($executable) :Bool >>

Return true if C<$executable> is installed in your system.

=head1 UTILITY CLASS

=head2 C<< Testgen::Util::Chdir >>

use like as follow:

   # CWD(Current working directory) is '/foo'

   {
       my $guard = Testgen::Util::Chdir->new('bar');
       # CWD is '/foo/bar'

       You do something in '/foo/bar'

       # When called destructor of $guard, CWD is restored.
   }

   # CWD is '/foo'

=cut
