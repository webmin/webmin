#!/usr/local/bin/perl
# save_group_quota.cgi
# Update the quota for some group

require './quota-lib.pl';
&ReadParse();
$bsize = &block_size($in{'filesys'});

&can_edit_group($in{'group'}) ||
	&error($text{'sgroup_egroup'});
$access{'ro'} && &error($text{'sgroup_egroup'});
&can_edit_filesys($in{'filesys'}) ||
	&error($text{'sgroup_efs'});
if ($bsize) {
	$in{'sblocks'} = &quota_parse("sblocks", $bsize);
	$in{'hblocks'} = &quota_parse("hblocks", $bsize);
	}
!$access{'maxblocks'} ||
	!$in{'sblocks_def'} && $in{'sblocks'} <= $access{'maxblocks'} &&
	!$in{'hblocks_def'} && $in{'hblocks'} <= $access{'maxblocks'} ||
		&error(&text('suser_emaxblocks', $access{'maxblocks'}));
!$access{'maxfiles'} ||
	!$in{'sfiles_def'} && $in{'sfiles'} <= $access{'maxfiles'} &&
	!$in{'hfiles_def'} && $in{'hfiles'} <= $access{'maxfiles'} ||
		&error(&text('suser_emaxfiles', $access{'maxfiles'}));
&edit_group_quota($in{'group'}, $in{'filesys'},
		  $in{'sblocks_def'} ? 0 : $in{'sblocks'},
		  $in{'hblocks_def'} ? 0 : $in{'hblocks'},
		  $in{'sfiles_def'} ? 0 : $in{'sfiles'},
		  $in{'hfiles_def'} ? 0 : $in{'hfiles'});
&webmin_log("save", "group", $in{'group'}, \%in);
if ($in{'source'}) {
	&redirect("group_filesys.cgi?group=".&urlize($in{'group'}));
	}
else {
	&redirect("list_groups.cgi?dir=".&urlize($in{'filesys'}));
	}

