#!/usr/local/bin/perl
# Save live rules to the config file, and activate at boot

require './ipfilter-lib.pl';
&error_setup($text{'convert_err'});
&ReadParse();

$err = &unapply_configuration();
&error($err) if ($err);

if ($in{'atboot'}) {
	&create_firewall_init();
	}
else {
	&delete_firewall_init();
	}

&webmin_log("convert");
&redirect("");

