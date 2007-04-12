#!/usr/local/bin/perl
# rhn_check.cgi
# Save redhat network checking options

require './software-lib.pl';
&ReadParse();
&foreign_require("init", "init-lib.pl");
&error_setup($text{'rhn_err'});
$conf = &read_up2date_config();

# Validate inputs
$in{'interval'} =~ /^\d+$/ || &error($text{'rhn_einterval'});
$in{'interval'} >= 120 || &error($text{'rhn_einterval2'});
!$in{'proxy_on'} && $in{'proxy'} eq '' ||
	$in{'proxy'} =~ /^http:\/\/\S+$/ || &error($text{'rhn_eproxy'});
@skip = split(/\s+/, $in{'skip'});

# Save and apply
&save_up2date_config($conf, "enableProxy", $in{'proxy_on'});
&save_up2date_config($conf, $conf->{'pkgProxy[comment]'} ? "pkgProxy" : "httpProxy", $in{'proxy'});
&save_up2date_config($conf, "pkgSkipList", join(";", @skip).";");
&flush_file_lines();
&read_env_file($rhn_sysconfig, \%rhnsd);
$rhnsd{'INTERVAL'} = $in{'interval'};
&write_env_file($rhn_sysconfig, \%rhnsd);
if ($in{'auto'}) {
	&init::enable_at_boot("rhnsd");
	}
else {
	&init::disable_at_boot("rhnsd");
	}
local $init = &init::action_filename("rhnsd");
&system_logged("$init stop >/dev/null 2>&1");
if ($in{'auto'}) {
	&system_logged("$init start >/dev/null 2>&1");
	}

if ($in{'now'}) {
	# Run rhn_check now ..
	&ui_print_unbuffered_header(undef, $text{'rhn_check'}, "");

	print "<b>",&text('rhn_checkdesc', "<tt>up2date -u</tt>"),"</b><p>\n";
	print "<pre>";
	&additional_log('exec', undef, "rhn_check");
	open(CMD, "up2date -u 2>&1 |");
	while(<CMD>) {
		while(s/^[^\015]+\015([^\012])/$1/) { }
		if (/\/([^\/\s]+)\-([^\-]+)\-([^\-]+)\.rpm/i) {
			push(@packs, $1);
			}
		print;
		}
	close(CMD);
	print "</pre>\n";

	@packs || print "<b>$text{'rhn_nocheck'}</b><p>\n";
	foreach $p (@packs) {
		local @pinfo = &show_package_info($p);
		}
	&webmin_log("rhn", "check", undef, { 'packages' => \@packs })
		if (@packs);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	&redirect("");
	}

