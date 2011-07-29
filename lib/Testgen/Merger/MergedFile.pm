package Testgen::Merger::MergedFile;
use strict;
use warnings;

use Carp ();
use Scalar::Util qw/blessed/;

use Testgen::Runner::Command;
use Testgen::Parser;

sub new {
    my ($class, %args) = @_;

    unless (exists $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    unless (blessed $args{compiler} eq 'Testgen::Runner::Compiler') {
        Carp::croak("'compiler' parameter isa Testgen::Runner::Compiler");
    }

    bless {
        fragments    => [],
        headers      => {},
        pseudo_mains => [],
        %args,
    }, $class;
}

sub add {
    my ($self, $file, $prefix) = @_;

    my $compiler = $self->{compiler};
    my ($preprocessed, $stderr) = $compiler->preprocess($file);

    my $parser   = Testgen::Parser->create_parser(
        lang     => 'c',
        compiler => $compiler->name,
    );
    my $c_source = $parser->remove_preprocessor_directives($preprocessed);
    my $modified = $parser->prepend_to_identifier($c_source, $prefix);

    my @missing_headers = $parser->find_missing_headers($stderr);

    push @{$self->{fragments}}, $modified;
    map { $self->{headers}->{$_} = 1 } @missing_headers;

    push @{$self->{pseudo_mains}}, "${prefix}_main";
}

sub output_as_main_file {
    my ($self, $file) = @_;

    my $headers_str   = $self->_include_statements_str;
    my $pseudo_main_str = join "\n", map { "$_();" } @{$self->{pseudo_mains}};
    my $fragments_str   = join "\n", @{$self->{fragments}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
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

    my $headers_str   = $self->_include_statements_str;
    my $fragments_str = join "\n", @{$self->{fragments}};

    open my $fh, '>', $file or Carp::croak("Can't open $file: $!");

    print {$fh} <<"...";
$headers_str

$fragments_str
...
    close $fh;
}

sub _include_statements_str {
    my $self = shift;
    return join "\n", map { "#include<${_}>" } keys %{$self->{headers}};
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Merger::MergedFile - A merged file class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Merger::MergedFile->new(%args) :Testgen::Merger::MergedFile >>

Creates and returns a new Testgen::Merger::MergedFile object with I<args>.

I<%args> might be:

=over

=item compiler :Testgen::Runner::Compiler

The compiler which used to merge files.

=back

=head2 Instance Methods

=head3 C<< $runner->add($file, $prefix)  >>

Add a C<$file> to merged files. C<$prefix> has a meaning
case of separate compilation.

=head3 C<< $runner->output_as_main_file >>

Generate file which contains 'main' function.

=head3 C<< $runner->output_as_sub_file >>

Generate file which does not contain 'main' function.

=cut
