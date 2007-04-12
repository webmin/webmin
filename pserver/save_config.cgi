#!/usr/local/bin/perl
# save_config.cgi
# Save server config options

require './pserver-lib.pl';
$access{'config'} || &error($text{'config_ecannot'});
&ReadParse();
&error_setup($text{'save_err'});

# Validate and save inputs
&lock_file($cvs_config_file);
@conf = &get_cvs_config();
if ($in{'auth'}) {
	&save_cvs_config(\@conf, "SystemAuth", undef, "yes");
	}
else {
	&save_cvs_config(\@conf, "SystemAuth", "no", "yes");
	}
if ($in{'top'}) {
	&save_cvs_config(\@conf, "TopLevelAdmin", "yes", "no");
	}
else {
	&save_cvs_config(\@conf, "TopLevelAdmin", undef, "no");
	}
if ($in{'hist_def'}) {
	&save_cvs_config(\@conf, "LogHistory", undef, "all");
	}
else {
	&save_cvs_config(\@conf, "LogHistory",
			 join("", split(/\0/, $in{'hist'})), "all");
	}
if ($in{'lock_def'}) {
	&save_cvs_config(\@conf, "LockDir", undef);
	}
else {
	-d $in{'lock'} || &error($text{'config_elock'});
	&save_cvs_config(\@conf, "LockDir", $in{'lock'});
	}
&flush_file_lines();
&unlock_file($cvs_config_file);
&webmin_log("config");
&redirect("");

