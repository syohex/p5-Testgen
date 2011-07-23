package Testgen::Runner::Compiler;
use strict;
use warnings;

use Carp ();

use Testgen::Runner::Command;
use Testgen::Runner::Compiler::Result;

sub new {
    my ($class, %args) = @_;

    unless (defined $args{compiler}) {
        Carp::croak("missing mandatory parameter 'compiler'");
    }

    my $c_flags  = delete $args{c_flags}  || [ '' ];
    my $ld_flags = delete $args{ld_flags} || [ '' ];
    my $options  = delete $args{options}  || [ '' ];

    bless {
        c_flags  => $c_flags,
        ld_flags => $ld_flags,
        options  => $options,
        %args,
    }, $class;
}

# accessor
sub options { shift->{options} }

sub compile {
    my ($self, $test, $option) = @_;

    my @cmd = $self->_create_cmd($test->input, $test->output, $option);
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

sub _create_cmd {
    my ($self, $input, $output, $option) = @_;
    $option ||= '';

    # for empty parameter
    my $cmd_str = join ' ', $self->{compiler}, @{$self->{c_flags}}
                          , $option, $input, '-o', $output
                          , @{$self->{ld_flags}};

    return split /\s+/, $cmd_str;
}

1;

__END__
