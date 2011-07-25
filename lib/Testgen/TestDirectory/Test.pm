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

    my $oknum = delete $args{oknum} || undef;
    my $files = delete $args{files};
    $files = [ $files ] unless ref $files eq 'ARRAY';

    my $output = _set_output($files);
    my $result = {
        test_num        => 0,
        compile_success => 0,
        compile_failure => 0,
        execute_success => 0,
        execute_failure => 0,
    };

    bless {
        files  => $files,
        oknum  => $oknum,
        output => $output,
        result => $result,
        %args,
    }, $class;
}

sub _set_output {
    my $files = shift;
    my $name = join '_', @{$files};
    return File::Basename::basename($name, '.c') . '.x';
}

# accessor
sub oknum  { shift->{oknum}  }
sub output { shift->{output} }

sub files  { @{shift->{files}} }

sub input {
    my $self = shift;
    return join ' ', @{$self->{files}};
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
    my $dump_file = File::Spec->catfile($dir, $self->{files}->[0]);

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

    my $oknum = 0;
    for my $file (@{$self->{files}}) {
        my $str = do {
            local $/;
            open my $fh, '<', $file or Carp::croak("Can't open $file: $!");
            <$fh>;
        };

        $oknum += _count_ok($str);
    }

    $self->{oknum} = $oknum;
    return $oknum;
}

my %ok_info_re = (
    testinfo => qr{
        /\*\* \s* test \s* info \s* \*\*
    }xms,

    testinfo_ok => qr{ \b OK: \s*(\d+)\s* }xms,

    printok => qr{ \b printok \( \s* \)   }xms,
);

sub _count_ok {
    my $str = shift;

    if ($str =~ m{ $ok_info_re{testinfo} }xms) {
        if ($str =~ m{ $ok_info_re{testinfo_ok} }xms) {
            return $1;
        } else {
            Carp::croak("Invalid 'test info' section");
        }
    }

    my $oknum = 0;
    $oknum += 1 while $str =~ m/ $ok_info_re{printok} /gxms;

    return $oknum;
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::TestDirectory::Test - A test class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::TestDirectory::Test->new(%args) :Testgen::TestDirectory::Test >>

Creates and returns a new Testgen::TestDirectory::Test object with I<args>.
Dies on error.

I<%args> might be:

=over

=item files :(Str|ArrayRef)

=item oknum :Int = undef

=back

=head2 Instance Methods

=head3 C<< $test->count_ok_num :Int >>

Count 'printok' in test file and return count of its.

=head3 C<< $test->analyze_result($compile_result, $execute_result) >>

Analyze compile result and execute result of this test program.

=head3 C<< $test->dump_result($dir) >>

Dump test result to C< File::Spec->catfile($dir, test_name) >.

=head3 C<< $test->finalize() >>

Finalize this test, remove executable.

=head3 C<< $template_file->parse() >>

=cut
