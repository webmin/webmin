#!/usr/local/bin/perl
# Convert two LVs into a thin pool

require './lvm-lib.pl';
&error_setup($text{'thin_err'});
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});

# Get the LVs, and make sure they aren't in use
my @lvs = &list_logical_volumes($in{'vg'});
my ($datalv) = grep { $_->{'name'} eq $in{'data'} } @lvs;
my ($metadatalv) = grep { $_->{'name'} eq $in{'metadata'} } @lvs;
$datalv->{'name'} ne $metadatalv->{'name'} ||
	&error($text{'thin_esame'});
!$datalv->{'is_snap'} && !&device_status($datalv->{'device'}) ||
	&error($text{'thin_edata'});
!$metadatalv->{'is_snap'} && !&device_status($metadatalv->{'device'}) ||
	&error($text{'thin_emetadata'});

# Convert to a thin pool
$err = &create_thin_pool($datalv, $metadatalv);
&error("<pre>$err</pre>") if ($err);
&webmin_log("thin", "lv", $in{'datalv'}, $datalv);
&redirect("index.cgi?mode=lvs");
