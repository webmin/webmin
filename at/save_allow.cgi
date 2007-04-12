#!/usr/local/bin/perl
# Update allowed or denied At users

require './at-lib.pl';
%access = &get_module_acl();
ReadParse();
&error_setup($text{'allow_err'});
$access{'allow'} || &error($text{'allow_ecannot'});

if ($in{'amode'} == 0) {
	&save_allowed();
	&save_denied();
	}
elsif ($in{'amode'} == 1) {
	@users = split(/\s+/, $in{'ausers'});
	@users || &error($text{'allow_eusers'});
	&save_allowed(@users);
	&save_denied();
	}
elsif ($in{'amode'} == 2) {
	@users = split(/\s+/, $in{'ausers'});
	@users || &error($text{'allow_eusers'});
	&save_allowed();
	&save_denied(@users);
	}
&webmin_log("allow");
&redirect("");

