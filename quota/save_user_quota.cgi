#!/usr/local/bin/perl
# save_user_quota.cgi
# Update the quota for some user

require './quota-lib.pl';
&ReadParse();
$bsize = &block_size($in{'filesys'});

&can_edit_user($in{'user'}) ||
	&error($text{'suser_euser'});
$access{'ro'} && &error($text{'suser_euser'});
&can_edit_filesys($in{'filesys'}) ||
	&error($text{'suser_efs'});
if ($bsize) {
	$in{'sblocks'} = &quota_parse("sblocks", $bsize);
	$in{'hblocks'} = &quota_parse("hblocks", $bsize);
	}
foreach my $field (qw(sblocks hblocks sfiles hfiles)) {
	&check_quota_limit($field, $in{$field.'_def'} ? 0 : $in{$field});
	}
&edit_user_quota($in{'user'}, $in{'filesys'},
		 $in{'sblocks_def'} ? 0 : $in{'sblocks'},
		 $in{'hblocks_def'} ? 0 : $in{'hblocks'},
		 $in{'sfiles_def'} ? 0 : $in{'sfiles'},
		 $in{'hfiles_def'} ? 0 : $in{'hfiles'});
&webmin_log("save", "user", $in{'user'}, \%in);
if ($in{'source'}) {
	&redirect("user_filesys.cgi?user=".&urlize($in{'user'}));
	}
else {
	&redirect("list_users.cgi?dir=".&urlize($in{'filesys'}));
	}


