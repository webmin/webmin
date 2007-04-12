#!/usr/local/bin/perl
# Enable or disable dovecot at boot time

require './dovecot-lib.pl';
&ReadParse();
&foreign_require("init", "init-lib.pl");
if ($in{'boot'}) {
	&init::enable_at_boot($config{'init_script'}, "Dovecot IMAP server",
			      $config{'dovecot'},
			      "kill `cat $config{'pid_file'}`");
	}
else {
	&init::disable_at_boot($config{'init_script'});
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("");

