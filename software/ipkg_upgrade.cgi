#!/usr/local/bin/perl
# Upgrade all packages, or update the database of IPKG packages

require './software-lib.pl';
&ReadParse();

# Work out what we are doing
if ($in{'upgrade'}) {
	$cmd = "ipkg upgrade";
	$mode = "upgrade";
	}
else {
	$cmd = "ipkg update";
	$mode = "update";
	}
	
&ui_print_unbuffered_header(undef, $text{'IPKG_title_'.$mode}, "");

local $out;
print "<b>",&text('IPKG_updatedesc', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log("exec", undef, $cmd);
&clean_environment();
open(CMD, "($cmd; ipkg list-upgradable) 2>&1 </dev/null |");
while(<CMD>) {
	print &html_escape($_);
	$out .= $_;
	}
print &html_escape("$text{'IPKG_noupgrade'}") if ($out eq "");
close(CMD);
&reset_environment();
print "</pre>\n";
if ($?) {
	print "<b>$text{'IPKG_upgradefailed'}</b><p>\n";
	}
else {
	print "<b>$text{'IPKG_upgradeok'}</b><p>\n";
	&webmin_log("IPKG", $mode)
	}

&ui_print_footer("", $text{'index_return'});

