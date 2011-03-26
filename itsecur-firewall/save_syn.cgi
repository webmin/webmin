#!/usr/bin/perl
# save_syn.cgi
# Save syn settings

require './itsecur-lib.pl';
&can_edit_error("syn");
&lock_itsecur_files();
&ReadParse();

&error_setup($text{'syn_err'});
$flood = $in{'flood'};
$spoof = $in{'spoof'};
$fin = $in{'fin'};
&automatic_backup();
&save_syn($flood, $spoof, $fin);
&unlock_itsecur_files();
&remote_webmin_log("update", "syn");
&redirect("");

