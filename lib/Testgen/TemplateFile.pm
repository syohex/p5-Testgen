package Testgen::TemplateFile;
use strict;
use warnings;

use Encode;
use File::Path ();

use Testgen::TemplateFile::Macro;
use Testgen::Util ();

use constant FILESET_NAME => 'FILESET';

sub new {
    my ($class, %args) = @_;

    my $macros = delete $args{macros} || {};

    bless {
        macros            => $macros,
        filename_index    => 0,
        template_encoding => 'utf8',
        output_encoding   => 'utf8',
        %args,
    }, $class;
}

my %dispatch_table = (
    def     => \&_parse_def_section,
    dir     => \&_parse_dir_section,
    comment => \&_parse_comment_section,
);

sub parse {
    my $self = shift;

    open my $fh, '<', $self->{name} or Carp::croak("Can't open $self->{name}");
    my $template_str = do {
        local $/;
        decode($self->{template_encoding}, <$fh>);
    };
    close $fh;

    my $section_regexp = qr{
        ^\@(\S+)
        (.*?)
        ^\@\1 _
    }xms;

    while ($template_str =~ m{ $section_regexp }gxms) {
        my ($section, $body) = ($1, $2);

        unless (exists $dispatch_table{$section}) {
            Carp::croak("Unknown section '$section'");
        }

        $dispatch_table{$section}->($self, $body);
    }
}

sub _parse_def_section {
    my ($self, $section) = @_;

    my $regexp = qr{
        \A
        \s+ ([^(]+)  \( ([^)]*) \) [^\n]*\n # $1=macro name $2=macro params
        (.+)                                # $3=macro body
        \z
    }xmso;

    if ($section =~ m{$regexp}) {
        my ($name, $param, $body) = ($1, $2, $3);

        my $macro = Testgen::TemplateFile::Macro->new(
            name       => $name,
            dummy_args => _exploit_dummy_args($param),
            body       => $body
        );
        $self->{macros}->{$name} = $macro;
    }
}

sub _exploit_dummy_args {
    my $str = shift;
    return [ map { s/(?:^\s*|\s*$)//g; $_ } split /[,]/, $str ];
}

sub _parse_dir_section {
    my ($self, $section) = @_;

    my $regexp = qr{
       \A
       \s+ (\S+) # $1=dir_name
        (.+)     # $2=body
       \z
    }xmso;

    if ($section =~ m{$regexp}) {
        my ($dirname, $body) = ($1, $2);

        my $testdir = File::Spec->catfile($self->{testsuite_dir}, $dirname);

        File::Path::rmtree([$testdir], 0, 0) if -d $testdir;
        File::Path::mkpath([$testdir], 0, 0777);

        {
            my $guard = Testgen::Util::Chdir->new($testdir);
            $self->_process_dir_section(\$body);
        }
    }
}

sub _parse_comment_section {
    # do nothing in 'comment' section
    return;
}

my %dir_section_regexp = (
    at_file => qr{
        \@file
        \s+
        (\S+)  # $1=filename
        \s+

        (
            \$[^(]+
            \( .* \)
        ) # $2=macro(args) (ex $macro0(INT))
        \s+
        (?:
            \@ok \s+ (\d+) \s+ \@ok_ # $3=oknum
            \s+
        )?
        \@file_
    }xmso,

    at_comment_begin => qr{ \A \@comment   }xmso,
    at_comment_end   => qr{ \A \@comment_  }xmso,
);

sub _process_dir_section {
    my ($self, $body_ref) = @_;

    open my $fh, '<', $body_ref or Carp::croak("Can't open bodyref");

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m{^\s*$};

        if ($line =~ m/ $dir_section_regexp{at_file} /xms) {
            my ($filename_tmpl, $macro_str, $oknum) = ($1, $2, $3);

            my ($macro_name, $macro_args) = _parse_macro_str($macro_str);
            $filename_tmpl =~ s{>>}{};

            my $macro = $self->{macros}->{$macro_name};

            my @real_args;
            if (scalar @{$macro_args} >= 2) {
                my $arg_combinations = _combination(@{$macro_args});
                @real_args = @{$arg_combinations};
            } elsif (scalar @{$macro_args} == 1)  {
                @real_args = map { [ $_ ] } @{$macro_args->[0]};
            } else {
                @real_args = ([]);
            }

            for my $real_arg (@real_args) {
                my $filename = $self->_define_filename($filename_tmpl);
                my $expanded = $macro->expand($real_arg, $self->{macros});
                $self->_output_test($filename, $expanded);

                if (defined $oknum) {
                    _append_fileset($filename, $oknum);
                }
            }
        } elsif ($line =~ m/ $dir_section_regexp{at_comment_begin} /xms) {
            _skip_comment_section($fh);
        }
    }
    close $fh;
}

sub _skip_comment_section {
    my $fh = shift;

    while (my $line = <$fh>) {
        last if $line =~ $dir_section_regexp{at_comment_end};
    }
}

sub _define_filename {
    my ($self, $filename_tmpl) = @_;

    my ($placeholder) = $filename_tmpl =~ m{(\?+)};
    return $filename_tmpl unless defined $placeholder;

    my $number = sprintf "%0*d", length $placeholder, $self->{filename_index};
    $filename_tmpl =~ s/\Q$placeholder\E/$number/;

    $self->{filename_index}++;
    return $filename_tmpl;
}

sub _append_fileset {
    my ($test, $oknum) = @_;

    open my $fh, '>>', FILESET_NAME or Carp::croak();
    print {$fh} "$test: $oknum\n";
    close $fh;
}

sub _parse_macro_str {
    my $str = shift;

    my ($name, $arg_str) = $str =~ m{\A([^(]+) \( (.*) \)\z}xms;

    my $regexp = qr{
       (?:
         (?: \[ ([^\]]+) \] ) # $1 = argument in brackets
         | (\w+)              # $2 = argument without brackets
       ) ,?
    }oxms;

    my @macro_args;
    while ( $arg_str =~ m{$regexp}gxms ) {
        if (defined $1) {
            my $str = $1;
            $str =~ s{(?:^\s+|\s+$)}{}g;
            push @macro_args, [ split /,/ , $str ];
        } elsif (defined $2) {
            my $str = $2;
            $str =~ s{(?:^\s+|\s+$)}{}g;
            push @macro_args, [ $str ];
        }
    }

    return ($name, \@macro_args);
}

sub _output_test {
    my ($self, $testfile, $content) = @_;

    open my $fh, '>', $testfile or Carp::croak("Can't open $testfile");
    print {$fh} encode($self->{output_encoding}, $content);
    close $fh;
}

# Copy from http://ja.doukaku.org/44/lang/perl/
sub _combination {
    my ($a1, $a2) = splice @_, 0, 2;
    my @result;
    for my $e1 (@$a1){
        for my $e2 (@$a2){
            push @result, [(ref $e1 ? @$e1 : $e1), $e2];
        }
    }
    @_ ?  _combination([@result], @_) : [ @result ];
}

1;

__END__

=encoding utf8

=head1 NAME

Testgen::TemplateFile - A template file class

=head1 INTERFACE

=head2 Class Methods

=head3 C<< Testgen::TemplateFile->new(%args) :Testgen::TemplateFile >>

Creates and returns a new Testgen::TemplateFile object with I<args>.
Dies on error.

I<%args> might be:

=over

=item macros :HashRef[] = {}

You set this parameter if you have predefined macros.

=item template_encoding :Str = 'utf8'

=item output_encodign :Str = 'utf8'

=back

=head2 Instance Methods

=head3 C<< $template_file->parse() >>

Parse this template file and generate test programs.

=cut
