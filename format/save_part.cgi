#!/usr/local/bin/perl
# save_part.cgi
# Save an existing partition

require './format-lib.pl';
$access{'view'} && &error($text{'ecannot'});
&ReadParse();

# check start and end
@dlist = &list_disks();
$dinfo = $dlist[$in{'disk'}];
&can_edit_disk($dinfo->{'device'}) ||
	&error($text{'save_ecannot'});
if ($in{delete}) {
	# unassigning a partition
	&error_setup($text{'save_edelete'});
	&modify_partition($in{'disk'}, $in{'part'}, "unassigned", "wu", "", "");
	&redirect("");
	}
else {
	# changing an existing partition
	&error_setup($text{'save_esave'});
	$in{start} =~ /^\d+$/ ||
		&error(&text('save_estart', $in{start}));
	$in{end} =~ /^\d+$/ ||
		&error(&text('save_eend', $in{end}));
	$in{start} >= 0 ||
		&error($text{'save_estartmin'});
	$in{end} < $dinfo->{'cyl'} ||
		&error(&text('save_eendmax', $dinfo->{'cyl'}));
	$in{start} < $in{end} ||
		&error($text{'save_estartend'});

	# make the change
	$flag = ($in{writable} ? "w" : "r").($in{mountable} ? "m" : "u");
	&modify_partition($in{disk}, $in{part}, $in{tag}, $flag,
			  $in{start}, $in{end});
	&redirect("");
	}

