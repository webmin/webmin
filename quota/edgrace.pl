#!/usr/local/bin/perl
# edgrace.pl
# Run by edquota to edit the grace times for some filesystem

$no_acl_check++;
$0 =~ /^(\S+)\//;
chdir($1);
require './quota-lib.pl';
$fs = $ENV{'QUOTA_FILESYS'};
$bt = $ENV{'QUOTA_BTIME'};
$bu = $ENV{'QUOTA_BUNITS'};
$ft = $ENV{'QUOTA_FTIME'};
$fu = $ENV{'QUOTA_FUNITS'};
$f = $ARGV[0];

open(FILE, $f);
while(<FILE>) { $qdata .= $_; }
close(FILE);
$nqdata = &edit_grace_file($qdata, $fs, $bt, $bu, $ft, $fu);
open(FILE, "> $f");
print FILE $nqdata;
close(FILE);
