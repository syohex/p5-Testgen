#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename ();

my $log = shift or die "$0 logfile";

my $basename = File::Basename::basename($log, '.log');
my $clog = "${basename}_compile.txt";
my $elog = "${basename}_execute.txt";

open my $cfh, '>', $clog or die "Can't open $clog: $!";
open my $efh, '>', $elog or die "Can't open $elog: $!";

map {
    print {$_} join "\t", qw/File Status Time(sec) Command/, "\n";
} ($cfh, $efh);

my $regexp = qr{
    ([^:]+): \s+ (\S+) # $1 acition $2 file
    \s+
    \(
        Status:(\S+)   # $3 status
        \s+
        Time:(\S+)     # $4 time
    \)
}xms;

open my $log_fh, '<', $log or die "Can't open $log: $!";

while (my $line = <$log_fh>) {
    chomp $line;

    if ($line =~ m{$regexp}xms) {
        my ($action, $file, $status, $time) = ($1, $2, $3, $4);

        my $tsv_fh = $action eq 'Compile' ? $cfh : $efh;

        my $next_line = <$log_fh>;
        chomp $next_line;

        if ($next_line =~ m{\A Command: \s+ (.+) \z}xms) {
            my $command = $1;
            print {$tsv_fh} join "\t", ($file, $status, $time, $command), "\n";
        }
    }
}

close $log_fh;

close $efh;
close $cfh;
