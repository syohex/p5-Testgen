package Testgen::Runner::Compiler;
use strict;
use warnings;

use Carp ();
use POSIX qw(:locale_h);

use Testgen::Runner::Command;
use Testgen::Runner::Compiler::Result;
use Testgen::Util ();

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
    my ($self, $test, @options) = @_;

    my @cmd = $self->_compile_command($test->input, $test->output, @options);
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

    # I should analyze preprocessor's error message.
    # So I hope that error message is English.
    my $old_locale = setlocale(LC_ALL);
    POSIX::setlocale(LC_ALL, "C");
    my ($status, $stdout, $stderr) = $preprocessor_cmd->run;
    POSIX::setlocale(LC_ALL, $old_locale);

    return ($stdout, $stderr);
}

sub _preprocess_command {
    my ($self, $file) = @_;

    my $compiler = $self->{name};
    my $c_flags  = $self->{c_flags};
    my $c_flags_str = scalar @{$c_flags} ? join ' ', @{$c_flags} : '';

    my $cmd_str;
    if ( Testgen::Util::which('gcc') ) {
        $cmd_str = join ' ', $compiler, '-E',
                      $c_flags_str, '-nostdinc', $file;
    } else {
        Carp::croak("You need 'gcc' for merging tests");
    }

    return split /\s+/, $cmd_str;
}

sub _compile_command {
    my ($self, $input, $output, @options) = @_;

    my $c_flags = $self->{c_flags};
    my $c_flags_str = scalar @{$c_flags} ? join ' ', @{$c_flags} : '';
    my $ld_flags = $self->{ld_flags};
    my $ld_flags_str = scalar @{$ld_flags} ? join ' ', @{$ld_flags} : '';
    my $options_str = scalar @options ? join ' ', @options : '';

    # for empty parameter
    my $cmd_str = join ' ', $self->{name}, $c_flags_str,
                          , $options_str
                          , $input, '-o', $output, $ld_flags_str;

    return split /\s+/, $cmd_str;
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::Runner::Compiler - Compiler class

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
