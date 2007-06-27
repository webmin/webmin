#!/usr/local/bin/perl
# Start or stop Bacula at boot

require './bacula-backup-lib.pl';
&ReadParse();
&foreign_require("init", "init-lib.pl");

if ($in{'boot'}) {
	foreach $p (@bacula_inits) {
		&init::enable_at_boot($p);
		}
	&webmin_log("bootup");
	}
else {
	foreach $p (@bacula_inits) {
		&init::disable_at_boot($p);
		}
	&webmin_log("bootdown");
	}
&redirect("");

