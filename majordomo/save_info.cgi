#!/usr/local/bin/perl
# save_info.cgi
# Store the info and intro message for a list

require './majordomo-lib.pl';
require 'ctime.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
&lock_file($list->{'config'});
&lock_file($list->{'info'});
&lock_file($list->{'intro'});
$conf = &get_list_config($list->{'config'});
chop($ctime = ctime(time()));
$updated = "[Last updated on: $ctime]\n";

$in{'info'} =~ s/\r//g;
&open_tempfile(INFO, ">$list->{'info'}");
if (&find_value("date_info", $conf) eq "yes") {
	&print_tempfile(INFO, $updated);
	}
&print_tempfile(INFO, $in{'info'});
&print_tempfile(INFO, "\n") if ($in{'info'} !~ /\n$/);
&close_tempfile(INFO);
if ($in{'intro_def'}) {
	unlink($list->{'intro'});
	}
else {
	$in{'intro'} =~ s/\r//g;
	&open_tempfile(INTRO, ">$list->{'intro'}");
	if (&find_value("date_intro", $conf) eq "yes") {
		&print_tempfile(INTRO, $updated);
		}
	&print_tempfile(INTRO, $in{'intro'});
	&print_tempfile(INTRO, "\n") if ($in{'intro'} !~ /\n$/);
	&close_tempfile(INTRO);
	&set_permissions($list->{'intro'});
	}
&save_list_directive($conf, $list->{'config'},
		     "description", $in{'description'});
&flush_file_lines();
&unlock_all_files();
&webmin_log("info", undef, $in{'name'});
&redirect("edit_list.cgi?name=$in{'name'}");

