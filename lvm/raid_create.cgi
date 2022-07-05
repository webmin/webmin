#!/usr/local/bin/perl
# Create a RAID logical volume

require './lvm-lib.pl';
&error_setup($text{'raid_err'});
&ReadParse();
($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
$vg || &error($text{'vg_egone'});

# Parse and validate inputs
&error_setup($text{'raid_err'});
$in{'name'} =~ /^[A-Za-z0-9\.\-\_]+$/ || &error($text{'lv_ename'});
($same) = grep { $_->{'name'} eq $in{'name'} }
	       &list_logical_volumes($in{'vg'});
$same && &error($text{'lv_esame'});
if ($in{'size_mode'} == 0) {
	# Absolute size
	$in{'size'} =~ /^\d+$/ || &error($text{'lv_esize'});
	$size = $in{'size'};
	if (defined($in{'size_units'})) {
		# Convert selected units to kB
		$size *= $in{'size_units'}/1024;
		}
	$sizeof = undef;
	}
elsif ($in{'size_mode'} == 1) {
	# Size of VG
	$in{'vgsize'} =~ /^\d+$/ &&
		$in{'vgsize'} > 0 &&
		$in{'vgsize'} <= 100 || &error($text{'lv_evgsize'});
	$size = $in{'vgsize'};
	$sizeof = 'VG';
	}
elsif ($in{'size_mode'} == 2) {
	# Size of free space
	if (!$in{'lv'}) {
		$in{'freesize'} =~ /^\d+$/ &&
			$in{'freesize'} > 0 &&
			$in{'freesize'} <= 100 || &error($text{'lv_efreesize'});
		}
	$size = $in{'freesize'};
	$sizeof = 'FREE';
	}
elsif ($in{'size_mode'} == 3) {
	# Size of some PV
	$in{'pvsize'} =~ /^\d+$/ &&
		$in{'pvsize'} > 0 &&
		$in{'pvsize'} <= 100 || &error($text{'lv_epvsize'});
	$size = $in{'pvsize'};
	$sizeof = $in{'pvof'};
	}
if ($in{'raid_mode'} eq 'raid0') {
	$in{'raid_stripe0'} =~ /^\d+$/ && $in{'raid_stripe0'} >= 2 ||
		&error($text{'raid_estripe0'});
	$stripes = $in{'raid_stripe0'};
	}
elsif ($in{'raid_mode'} eq 'raid1') {
	$in{'raid_mirror1'} =~ /^\d+$/ && $in{'raid_mirror1'} >= 1 ||
		&error($text{'raid_emirror1'});
	$mirrors = $in{'raid_mirror1'};
	}
elsif ($in{'raid_mode'} eq 'raid4') {
	$in{'raid_stripe4'} =~ /^\d+$/ && $in{'raid_stripe4'} >= 2 ||
		&error($text{'raid_estripe4'});
	$stripes = $in{'raid_stripe4'};
	}
elsif ($in{'raid_mode'} eq 'raid5') {
	$in{'raid_stripe5'} =~ /^\d+$/ && $in{'raid_stripe5'} >= 2 ||
		&error($text{'raid_estripe5'});
	$stripes = $in{'raid_stripe5'};
	}
elsif ($in{'raid_mode'} eq 'raid6') {
	$in{'raid_stripe6'} =~ /^\d+$/ && $in{'raid_stripe6'} >= 2 ||
		&error($text{'raid_estripe6'});
	$stripes = $in{'raid_stripe6'};
	}
elsif ($in{'raid_mode'} eq 'raid10') {
	$in{'raid_stripe10'} =~ /^\d+$/ && $in{'raid_stripe10'} >= 2 ||
		&error($text{'raid_estripe10'});
	$stripes = $in{'raid_stripe10'};
	}
$mirrors || $stripes || &error($text{'raid_eeither'});

# Create the LV
$lv = { };
$lv->{'vg'} = $in{'vg'};
$lv->{'name'} = $in{'name'};
$lv->{'size'} = $size;
$lv->{'size_of'} = $sizeof;
$lv->{'raid'} = $in{'raid_mode'};
$lv->{'mirrors'} = $mirrors;
$lv->{'stripes'} = $stripes;
$lv->{'perm'} = $in{'perm'};
$lv->{'alloc'} = $in{'alloc'};
$lv->{'readahead'} = $in{'readahead'};
$err = &create_raid_volume($lv);
&error($err) if ($err);

&webmin_log("raid", "lv", $in{'name'}, $lv);
&redirect("index.cgi?mode=lvs");
