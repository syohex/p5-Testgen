package Testgen::Runner::Compiler;
use strict;
use warnings;

use Carp ();

use Testgen::Runner::Command;
use Testgen::Runner::Compiler::Result;

sub new {
    my ($class, %args) = @_;

    unless (defined $args{name}) {
        Carp::croak("missing mandatory parameter 'name'");
    }

    my $c_flags  = delete $args{c_flags}  || [];
    my $ld_flags = delete $args{ld_flags} || [];

    bless {
        c_flags  => $c_flags,
        ld_flags => $ld_flags,
        %args,
    }, $class;
}

# accessor
sub name { shift->{name} }

sub compile {
    my ($self, $test, $option) = @_;
    $option ||= '';

    my @cmd = $self->_compile_command($test->input, $test->output, $option);
    my $command = Testgen::Runner::Command->new( command => \@cmd );

    my ($exit_status, undef, $stderr) = $command->run;

    my $status;
    if ($exit_status == 0) {
        if ($stderr eq '') {
            $status = 'success';
        } else {
            $status  = 'warn';
        }
    } else {
        $status = 'error';
    }

    return Testgen::Runner::Compiler::Result->new(
        command => "@cmd",
        status  => $status,
        message => $stderr,
    );
}

sub preprocess {
    my ($self, $file) = @_;

    my @cmd = $self->_preprocess_command($file);
    my $preprocessor_cmd = Testgen::Runner::Command->new(
        command => \@cmd,
    );

    my ($status, $stdout, $stderr) = $preprocessor_cmd->run;

    return ($stdout, $stderr);
}

sub _preprocess_command {
    my ($self, $file) = @_;

    if ($self->{name} eq 'gcc') {
        my $c_flags = $self->{c_flags};
        my $c_flags_str = scalar @{$c_flags} ? join ' ', @{$c_flags} : '';
        my $cmd_str = join ' ', $self->{name}, '-E',
                              $c_flags_str, '-nostdinc', $file;

        return split /\s+/, $cmd_str;
    } else {
        Carp::croak("'$self->{name}' is not supported");
    }
}

sub _compile_command {
    my ($self, $input, $output, $option) = @_;
    $option ||= '';

    my $c_flags = $self->{c_flags};
    my $c_flags_str = scalar @{$c_flags} ? join ' ', @{$c_flags} : '';
    my $ld_flags = $self->{ld_flags};
    my $ld_flags_str = scalar @{$ld_flags} ? join ' ', @{$ld_flags} : '';

    # for empty parameter
    my $cmd_str = join ' ', $self->{name}, $c_flags_str,
                          , $option, $input, '-o', $output, $ld_flags_str;

    return split /\s+/, $cmd_str;
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Compiler - A compiler class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::Runner::Compiler->new(%args) :Testgen::Runner::Compiler >>

Creates and returns a new Testgen::Runner::Compiler object with I<args>.
Dies on error.

I<%args> might be:

=over

=item compiler :Str

=item c_flags  :ArrayRef[Str] = []

=item ld_flags :ArrayRef[Str] = []

=back

=head2 Instance Methods

=head3 C<< $compiler->compile($test, $option) >>

Compile test which is a F<Testgen::Runner::Testdirectory::Test> with C<$option>.
Return a L<Testgen::Runner::Compiler::Result> object.

=cut
