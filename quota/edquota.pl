#!/usr/local/bin/perl
# edquota.pl
# Run by edquota to edit some user's quota

$no_acl_check++;
$0 =~ /^(\S+)\//;
chdir($1);
require './quota-lib.pl';
$u = $ENV{'QUOTA_USER'};
$fs = $ENV{'QUOTA_FILESYS'};
$sb = $ENV{'QUOTA_SBLOCKS'};
$hb = $ENV{'QUOTA_HBLOCKS'};
$sf = $ENV{'QUOTA_SFILES'};
$hf = $ENV{'QUOTA_HFILES'};
$f = $ARGV[0];

open(FILE, "<".$f);
while(<FILE>) { $qdata .= $_; }
close(FILE);
$nqdata = &edit_quota_file($qdata, $fs, $sb, $hb, $sf, $hf);
open(FILE, ">".$f);
print FILE $nqdata;
close(FILE);
