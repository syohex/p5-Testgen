package t::Util;
use strict;
use warnings;

use base qw(Exporter);
use File::Temp;
use Data::Dumper;

our @EXPORT = qw/create_configfile create_tmp_file/;

sub create_configfile {
    my $config = shift;

    my $tmp = File::Temp->new( UNLINK => 1 );
    print {$tmp} Data::Dumper::Dumper($config);
    $tmp->autoflush(1);

    return $tmp;
}

sub create_tmp_file {
    my (%args) = @_;

    for my $param (qw/content suffix/) {
        unless (exists $args{$param}) {
            die("missing mandatory parameter '$param'");
        }
    }

    my $tmp = File::Temp->new(SUFFIX => $args{suffix}, UNLINK => 1);
    print {$tmp} $args{content};
    $tmp->autoflush(1);

    if (exists $args{permission}) {
        chmod $args{permission}, $tmp->filename or die "Can't set permission";
    }

    return $tmp;
}

1;
