#!/usr/local/bin/perl
# move.cgi
# Move a restriction up or down

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ReadParse();
&lock_file("$config{'usermin_dir'}/usermin.mods");
@usermods = &list_usermin_usermods();
$i = $in{'idx'};
if ($in{'up'}) {
	($usermods[$i], $usermods[$i-1]) = ($usermods[$i-1], $usermods[$i]);
	}
else {
	($usermods[$i], $usermods[$i+1]) = ($usermods[$i+1], $usermods[$i]);
	}
&save_usermin_usermods(\@usermods);
&unlock_file("$config{'usermin_dir'}/usermin.mods");
&webmin_log("move", "restrict", $usermods[$i]->[0]);
&redirect("list_restrict.cgi");

