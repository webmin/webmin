#!/usr/local/bin/perl
# Upgrade all packages, or update the database of URPMI packages

require './software-lib.pl';
&ReadParse();

# Work out what we are doing
if ($in{'upgrade'}) {
	$cmd = "urpmi --force --auto-select";
	$mode = "upgrade";
	}
else {
	$cmd = "urpmi.update -a";
	$mode = "update";
	}
	
&ui_print_unbuffered_header(undef, $text{'urpmi_title_'.$mode}, "");

print "<b>",&text('urpmi_updatedesc', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log("exec", undef, $cmd);
&clean_environment();
open(CMD, "$cmd 2>&1 </dev/null |");
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
&reset_environment();
print "</pre>\n";
if ($?) {
	print "<b>$text{'uprmi_upgradefailed'}</b><p>\n";
	}
else {
	print "<b>$text{'urpmi_upgradeok'}</b><p>\n";
	&webmin_log("urpmi", $mode)
	}

&ui_print_footer("?tab=update", $text{'index_return'});

