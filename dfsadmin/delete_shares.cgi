#!/usr/local/bin/perl
# Delete several shares at once

require './dfs-lib.pl';
&error_setup($text{'delete_err'});
$access{'view'} && &error($text{'ecannot'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

&lock_file($config{'dfstab_file'});
@shlist = &list_shares();
foreach $d (sort { $b <=> $a } @d) {
	$share = $shlist[$d];
	&delete_share($share);
	}
&unlock_file($config{'dfstab_file'});
&webmin_log("delete", "shares", scalar(@d));
&redirect("");

