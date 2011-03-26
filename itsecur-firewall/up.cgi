#!/usr/bin/perl
# up.cgi
# Move a rule up

require './itsecur-lib.pl';
&can_edit_error("rules");
&ReadParse();
&lock_itsecur_files();
@rules = &list_rules();
($rules[$in{'idx'}], $rules[$in{'idx'}-1]) =
	($rules[$in{'idx'}-1], $rules[$in{'idx'}]);
&save_rules(@rules);
&unlock_itsecur_files();
&remote_webmin_log("move", "rule", $in{'idx'}+1, $rules[$in{'idx'}]);
&redirect("list_rules.cgi");

