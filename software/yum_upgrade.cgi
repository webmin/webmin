#!/usr/local/bin/perl
# yum_upgrade.cgi
# Upgrade all packages

require './software-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'yum_upgrade'}, "");

&clean_environment();
$cmd = "yum clean all ; yum -y update";
print "<b>",&text('yum_upgradedesc', "<tt>$cmd</tt>"),"</b><p>\n";
print "<pre>";
&additional_log("exec", undef, $cmd);
open(CMD, "$cmd 2>&1 </dev/null |");
while(<CMD>) {
	if (/^\[(update|install):\s+(\S+)\s+/) {
		push(@packs, $2);
		}
	if (!/ETA/ && !/\%\s+done\s+\d+\/\d+\s*$/) {
		print &html_escape($_);
		}
	}
close(CMD);
&reset_environment();
print "</pre>\n";
if ($?) {
	print "<b>$text{'yum_upgradefailed'}</b><p>\n";
	}
else {
	print "<b>$text{'yum_upgradeok'}</b><p>\n";
	foreach $p (@packs) {
		local @pinfo = &show_package_info($p);
		}
	&webmin_log("yum", "upgrade", undef, { 'packages' => \@packs })
		if (@packs);
	}

&ui_print_footer("", $text{'index_return'});

