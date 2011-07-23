package Testgen::TestDirectory::Test;
use strict;
use warnings;

use Carp ();
use Data::Dumper;
use File::Basename ();
use File::Spec ();

use Testgen::Util ();

local $Data::Dumper::Indent = 0;

sub new {
    my ($class, %args) = @_;

    unless (exists $args{files}) {
        Carp::croak("missing mandatory parameter 'files'");
    }

    my $oknum  = delete $args{oknum} || undef;
    my $output = _set_output($args{files});
    my $result = {
        test_num        => 0,
        compile_success => 0,
        compile_failure => 0,
        execute_success => 0,
        execute_failure => 0,
    };

    bless {
        oknum           => $oknum,
        output          => $output,
        result          => $result,
        %args,
    }, $class;
}

sub _set_output {
    my $files = shift;
    return File::Basename::basename(_first_file($files), '.c') . '.x';
}

# accessor
sub oknum           { shift->{oknum}    }
sub output          { shift->{output}   }
sub log             { shift->{result}->{log}             }
sub faillog         { shift->{result}->{faillog}         }
sub test_num        { shift->{result}->{test_num}        }
sub compile_success { shift->{result}->{compile_success} }
sub compile_failure { shift->{result}->{compile_failure} }
sub execute_success { shift->{result}->{execute_success} }
sub execute_failure { shift->{result}->{execute_failure} }

sub input {
    my $self = shift;
    my $files = $self->{files};
    ref $files eq 'ARRAY' ? join ' ', @{$files} : $files;
}

sub _first_file {
    my $files = shift;
    return ref $files eq 'ARRAY' ? $files->[0] : $files;
}

sub finalize {
    my $self = shift;

    if (-e $self->{output}) {
        unlink $self->{output} or Carp::croak("Can't unlink $self->{output}\n");
    }
}

sub analyze_result {
    my ($self, $compile_result, $execute_result) = @_;

    my $result = $self->{result};
    $result->{test_num}++;

    if (defined $compile_result) {
        if ($compile_result->is_error) {
            $result->{compile_failure}++;
        } else {
            # warning is success
            $result->{compile_success}++;
        }

        $self->_compile_log($compile_result);
    }

    if (defined $execute_result) {
        if ($execute_result->is_success) {
            $result->{execute_success}++;
        } else {
            $result->{execute_failure}++;
        }

        $self->_execute_log($execute_result);
    }
}

sub dump_result {
    my ($self, $dir) = @_;

    my $name = _first_file($self->{files});
    my $dump_file = File::Spec->catfile($dir, $name);

    open my $fh, '>', $dump_file or Carp::croak("Can't open $dump_file $!");
    print {$fh} Data::Dumper::Dumper( $self->{result} );
    close $fh;
}

sub _compile_log {
    my ($self, $result) = @_;

    my ($command, $message) = ($result->command, $result->message);
    my $testname = File::Spec->catfile($self->{dir}, $self->input);

    chomp $message;
    $self->{result}->{log} = <<"...";
$testname
Compile: $command
$message
...

    unless ($result->is_success) {
        my $status = $result->status;
        $self->{result}->{faillog} = "$testname compile $status\n"
    }
}

sub _execute_log {
    my ($self, $result) = @_;

    my $oknum = $self->{oknum};
    my ($command, $message) = ($result->command, $result->message);
    my $testname = File::Spec->catfile($self->{dir}, $self->input);

    chomp $message;
    $self->{result}->{log} = <<"...";
$testname
Execute: $command
  (expect ok: $oknum) .....
$message
...

    unless ($result->is_success) {
        my $status = $result->status;
        $self->{result}->{faillog} = "$testname execute $status\n";
    }
}

sub count_ok_num {
    my $self = shift;

    my @files = ref $self->{files} eq 'ARRAY'
                    ? @{$self->{files}} : ($self->{files});

    my $oknum = 0;
    for my $file (@files) {
        $oknum += Testgen::Util::count_ok_from_file($file);
    }

    $self->{oknum} = $oknum;
    return $oknum;
}

1;
