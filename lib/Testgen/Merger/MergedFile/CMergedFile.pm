package Testgen::Merger::MergedFile::CMergedFile;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw/blessed/;

use Testgen::Runner::Command;
use Testgen::Parser;

sub new {
    my ($class, %args) = @_;

    my $caller = (caller)[0];
    unless ($caller eq 'Testgen::Merger::MergedFile') {
        Carp::croak("Can't call constructor directly");
    }

    unless (exists $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    unless (blessed $args{compiler} eq 'Testgen::Runner::Compiler') {
        Carp::croak("'compiler' parameter isa Testgen::Runner::Compiler");
    }

    my $parser   = Testgen::Parser->create_parser(
        lang     => 'c',
    );

    bless {
        fragments    => [],
        headers      => {},
        pseudo_mains => [],
        parser       => $parser,
        %args,
    }, $class;
}

sub add {
    my ($self, $file, $prefix) = @_;

    my ($compiler, $parser) = ($self->{compiler}, $self->{parser});
    my ($preprocessed, $stderr) = $compiler->preprocess($file);

    my $c_source = $parser->remove_preprocessor_directives($preprocessed);
    my $modified = $parser->prepend_to_identifier($c_source, $prefix);

    my @missing_headers = $parser->find_missing_headers($stderr);

    push @{$self->{fragments}}, $modified;
    map { $self->{headers}->{$_} = 1 } @missing_headers;

    push @{$self->{pseudo_mains}}, "${prefix}_main";
}

sub output_as_main_file {
    my $self = shift;

    my $headers_str   = $self->_include_statements_str;
    my $pseudo_main_str = join "\n", map { "$_();" } @{$self->{pseudo_mains}};
    my $fragments_str   = join "\n", @{$self->{fragments}};

    return <<"...";
$headers_str

int main ()
{

$pseudo_main_str

    return 0;
}

$fragments_str
...
}

sub output_as_sub_file {
    my ($self, $file) = @_;

    my $headers_str   = $self->_include_statements_str;
    my $fragments_str = join "\n", @{$self->{fragments}};

    return <<"...";
$headers_str

$fragments_str
...
}

sub _include_statements_str {
    my $self = shift;
    return join "\n", map { "#include<${_}>" } keys %{$self->{headers}};
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Merger::MergedFile::CMergedFile - Merged C file class

=head1 INTERFACE

=head2 Constructor

You can't call C<Testgen::Merger::MergedFile::CMergedFile->new> directly.
You can call constructor of this class via
C<Testgen::Merger::MergedFile->create_mergedfile>.

Arguments are:

=over

=item compile :Testgen::Runner::Compiler

A compiler is used for merging.

=back

=head2 Instance Methods

=head3 C<< $merged_file->add($file, $prefix)  >>

Add a C<$file> to merged files. C<$prefix> has a meaning
case of separate compilation.

=head3 C<< $merged_file->output_as_main_file >>

Generate file which contains 'main' function.

=head3 C<< $merged_file->output_as_sub_file >>

Generate file which does not contain 'main' function.

=cut
