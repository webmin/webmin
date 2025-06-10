#!/usr/local/bin/perl
# Enable or disable crond at boot time

require './cron-lib.pl';
&ReadParse();
&foreign_require("init");
$access{'stop'} || &error($text{'bootup_ecannot'});
$init = $config{'init_name'};
if ($in{'boot'}) {
	&init::enable_at_boot($init);
	}
else {
	&init::disable_at_boot($init);
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("");

