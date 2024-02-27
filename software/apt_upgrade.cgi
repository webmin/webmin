#!/usr/local/bin/perl
# apt_upgrade.cgi
# Upgrade a debian system

require './software-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'apt_upgrade'}, "");

if ($in{'update'}) {
	print "<b>",&text('apt_updatedesc',
			  "<tt>$apt_get_command update</tt>"),"</b><p>\n";
	print "<pre>";
	&additional_log("exec", undef, "$apt_get_command update");
	&clean_environment();
	open(CMD, "$apt_get_command update 2>&1 </dev/null |");
	while(<CMD>) {
		print &html_escape($_);
		}
	close(CMD);
	&reset_environment();
	print "</pre>\n";
	if ($?) {
		print "<b>$text{'apt_updatefailed'}</b><p>\n";
		&ui_print_footer("?tab=update", $text{'index_return'});
		exit;
		}
	else { print "<b>$text{'apt_updateok'}</b><p>\n"; }
	}

if ($in{'mode'}) {
	$opts = $in{'sim'} ? "-s -y -f" : "-y -f";
	$cmd = $in{'mode'} == 2 ? "dist-upgrade" :
	       $apt_get_command =~ /aptitude/ ? "safe-upgrade" : "upgrade";
	print "<b>",&text($in{'sim'} ? 'apt_upgradedescsim' : 'apt_upgradedesc', "<tt>$apt_get_command $opts $cmd</tt>"),"</b><p>\n";
	print "<pre>";
	&additional_log("exec", undef, "$apt_get_command $opts $cmd");
	&clean_environment();
	open(CMD, "$apt_get_command $opts $cmd 2>&1 </dev/null |");
	while(<CMD>) {
		if (/setting\s+up\s+(\S+)/i) {
			push(@packs, $1);
			}
		elsif (/packages\s+will\s+be\s+upgraded/i ||
		       /new\s+packages\s+will\s+be\s+installed/i) {
			print &html_escape($_);
			$line = $_ = <CMD>;
			$line =~ s/^\s+//; $line =~ s/\s+$//;
			push(@newpacks, split(/\s+/, $line));
			}
		print;
		}
	close(CMD);
	&reset_environment();
	if (!@rv && $config{'package_system'} ne 'debian' && !$?) {
		# Other systems don't list the packages installed!
		@packs = @newpacks;
		}
	print "</pre>\n";
	if ($?) { print "<b>$text{'apt_upgradefailed'}</b><p>\n"; }
	else { print "<b>$text{'apt_upgradeok'}</b><p>\n"; }

	foreach $p (@packs) {
		local @pinfo = &show_package_info($p);
		}
	&webmin_log("apt", "check", undef, { 'packages' => \@packs })
		if (@packs);
	}

&ui_print_footer("?tab=update", $text{'index_return'});

