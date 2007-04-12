#!/usr/local/bin/perl
# Delete several virtusers

require './sendmail-lib.pl';
require './virtusers-lib.pl';
&ReadParse();
&error_setup($text{'vdelete_err'});
$conf = &get_sendmailcf();
$vfile = &virtusers_file($conf);
($vdbm, $vdbmtype) = &virtusers_dbm($conf);

# Find and validate
@d = split(/\0/, $in{'d'});
@d || &error($text{'adelete_enone'});
@virts = &list_virtusers($vfile);
foreach $d (@d) {
	($virt) = grep { $_->{'from'} eq $d } @virts;
	if ($virt) {
		&can_edit_virtuser($virt) ||
			&error(&text('vdelete_ecannot', $d));
		push(@delvirts, $virt);
		}
	}

# Delete the aliases
&lock_file($vfile);
foreach $virt (@delvirts) {
	&delete_virtuser($virt, $vfile, $vdbm, $vdbmtype);
	}
&unlock_file($vfile);

&webmin_log("delete", "virtusers", scalar(@delvirts));
&redirect("list_virtusers.cgi");

