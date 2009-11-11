#!/usr/local/bin/perl
# Upgrade all CSW packages

require './software-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'csw_upgrade'}, "");

print "<b>",&text('csw_updatedesc',
		  "<tt>$pkg_get upgrade</tt>"),"</b><p>\n";
print "<pre>";
&additional_log("exec", undef, "$pkg_get upgrade");
&clean_environment();
$flag = $pkg_get =~ /pkgutil/ ? "--upgrade" : "upgrade";
open(CMD, "yes y | $pkg_get $flag 2>&1 </dev/null |");
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
&reset_environment();
print "</pre>\n";

&ui_print_footer("", $text{'index_return'});

