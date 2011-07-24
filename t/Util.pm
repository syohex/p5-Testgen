package t::Util;
use strict;
use warnings;

use base qw(Exporter);
use File::Temp;
use Data::Dumper;

our @EXPORT = qw/create_configfile create_template_file/;

sub create_configfile {
    my $config = shift;

    my $tmp = File::Temp->new( UNLINK => 1 );
    print {$tmp} Data::Dumper::Dumper($config);
    $tmp->autoflush(1);

    return $tmp;
}

sub create_template_file {
    my $content = shift;

    my $tmp = File::Temp->new(SUFFIX => '.tt', UNLINK => 1);
    print {$tmp} $content;
    $tmp->autoflush(1);

    return $tmp;
}

1;
