package Testgen::Merger::MergedFile;
use strict;
use warnings;

use Carp ();

use Testgen::Runner::Command;
use Testgen::Parser;

sub new {
    my ($class, %args) = @_;

    unless (exists $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    bless {
        fragments    => [],
        header       => {},
        pseudo_mains => [],
        files        => {},
        %args,
    }, $class;
}

sub add {
    my ($self, $file, $prefix) = @_;

    my $compiler = $self->{compiler};
    my ($preprocessed, $stderr) = $compiler->preprocess($file);

    my $parser   = Testgen::Parser->new(
        lang     => 'c',
        compiler => $compiler->name,
    );
    my $c_source = $parser->remove_preprocessor_directives($preprocessed);
    my $modified = $parser->prepend_to_identifier($c_source, $prefix);

    my @missing_headers = $parser->find_missing_headers($stderr);

    push @{$self->{fragments}}, $modified;
    map { $self->{header}->{$_} = 1 } @missing_headers;

    push @{$self->{pseudo_mains}}, "${prefix}_main";
}

sub output_as_main_file {
    my ($self, $file) = @_;

    my $headers_str     = join "\n", keys %{$self->{headers}};
    my $pseudo_main_str = join "\n", map { "$_();" } @{$self->{pseudo_mains}};
    my $fragments_str   = join "\n", @{$self->{fragments}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
#ifdef unix
#include <stdio.h>
#endif
$headers_str

int main ()
{

$pseudo_main_str

    return 0;
}

$fragments_str
...

    close $fh;
}

sub output_as_sub_file {
    my ($self, $file) = @_;

    my $headers_str   = join "\n", keys %{$self->{headers}};
    my $fragments_str = join "\n", @{$self->{fragments}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
#ifdef unix
#include <stdio.h>
#endif
$headers_str

$fragments_str
...
    close $fh;
}

1;

__END__
