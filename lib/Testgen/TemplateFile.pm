package Testgen::TemplateFile;
use strict;
use warnings;

use Carp ();
use Encode;
use File::Basename ();
use File::Path ();

use Testgen::TemplateFile::Macro;
use Testgen::Util ();

sub new {
    my ($class, %args) = @_;

    for my $param (qw/name testsuite_dir/) {
        unless (exists $args{$param}) {
            Carp::croak("missing mandatory parameter '$param'");
        }
    }

    my $macros = delete $args{macros} || {};
    my $include_path = delete $args{include_path} || [];

    # Add default include path, which is same as template file directory
    unshift @{$include_path}, File::Basename::dirname($args{name});

    bless {
        macros            => $macros,
        include_path      => $include_path,
        filename_index    => 0,
        template_encoding => 'utf8',
        output_encoding   => 'utf8',
        %args,
    }, $class;
}

my %dispatch_table = (
    def     => \&_parse_def_section,
    dir     => \&_parse_dir_section,
    include => \&_parse_include_section,
    comment => \&_parse_comment_section,
);

sub parse {
    my $self = shift;
    $self->_parse_string( $self->_read_file($self->{name}) );
}

sub _parse_string {
    my ($self, $str) = @_;

    my $section_regexp = qr{
        ^\@(\S+)
        (.*?)
        ^\@\1 _
    }xms;

    while ($str =~ m{ $section_regexp }gxms) {
        my ($section, $body) = ($1, $2);

        unless (exists $dispatch_table{$section}) {
            Carp::croak("Unknown section '$section'");
        }

        $dispatch_table{$section}->($self, $body);
    }
}

sub _read_file {
    my ($self, $file) = @_;
    my @lines;

    open my $fh, '<', $file or Carp::croak("Can't open $file");

    my @sections;
    my $current_line = 1;
    while (my $line = <$fh>) {
        chomp $line;

        if ($line =~ m{^\@([^_\s]+)_}) {
            my $section = $1;

            unless (@sections) {
                Carp::croak("Found only '$section' end at $current_line");
            }

            my $last_section = (pop @sections)->[0];
            if ($section ne $last_section) {
                Carp::croak("Not collect '$last_section' correspondence "
                            . "at $current_line");
            }
        } elsif ($line =~ m{^\@([^_\s]+)}) {
            my $section = $1;

            unless ($line =~ m{\@ $section _ \s* $}x) {
                push @sections, [ $section, $current_line ];
            }
        }

        push @lines, $line;
        $current_line++;
    }

    close $fh;

    if (@sections) {
        my @messages;
        for my $section (@sections) {
            my ($name, $line) = @{$section};
            push @messages, "'$name' section does not have end of section(at $line)";
        }

        my $error_num = scalar @sections;
        push @messages, "$file has $error_num errors";
        die join "\n", @messages;
    }

    return join "\n", @lines;
}

sub _parse_include_section {
    my ($self, $filename) = @_;
    $filename =~ s{\A\s*|\s*\z}{}gxms;

    my $include_file;
    for my $path ( @{$self->{include_path}} ) {
        my $filepath = $filename;

        unless (File::Spec->file_name_is_absolute($filename)) {
            $filepath = File::Spec->catfile($path, $filename);
        }

        if ( -e $filepath ) {
            $include_file = $filepath;
            last;
        }
    }

    unless (defined $include_file) {
        Carp::croak("'$filename' is not found");
    }

    $self->_parse_string( $self->_read_file($include_file) );
}

sub _parse_def_section {
    my ($self, $macro_def) = @_;

    my $regexp = qr{
        \A
        \s+ ([^(]+)  \( ([^)]*) \) [^\n]*\n # $1=macro name $2=macro params
        (.+)                                # $3=macro body
        \z
    }xmso;

    if ($macro_def =~ m{$regexp}) {
        my ($name, $param, $body) = ($1, $2, $3);

        my $dummy_args = _exploit_dummy_args($param);
        if ( grep { $_ eq '' } @{$dummy_args} ) {
            Carp::croak("'$name' has empty argument($param). Check params");
        }

        my $macro = Testgen::TemplateFile::Macro->new(
            name       => $name,
            dummy_args => $dummy_args,
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
        File::Path::mkpath([$testdir], 0, oct(777));

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
                my $arg_combinations = Testgen::Util::combination(@{$macro_args});
                @real_args = @{$arg_combinations};
            } elsif (scalar @{$macro_args} == 1)  {
                @real_args = map { [ $_ ] } @{$macro_args->[0]};
            } else {
                @real_args = ([]);
            }

            for my $real_arg (@real_args) {
                my $filename = $self->_decide_filename($filename_tmpl);
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

sub _decide_filename {
    my ($self, $filename_tmpl) = @_;

    my ($placeholder) = $filename_tmpl =~ m{(\?+)};
    return $filename_tmpl unless defined $placeholder;

    my $number = sprintf "%0*d", length $placeholder, $self->{filename_index};
    my $quoted = quotemeta $placeholder;
    (my $replaced = $filename_tmpl) =~ s/$quoted/$number/;

    $self->{filename_index}++;
    return $replaced;
}

sub _append_fileset {
    my ($test, $oknum) = @_;

    open my $fh, '>>', 'FILESET' or Carp::croak();
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

1;

__END__

=encoding utf8

=head1 NAME

Testgen::TemplateFile - Template file class

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
