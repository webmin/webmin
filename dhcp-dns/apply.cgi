#!/usr/local/bin/perl
# Apply the current configuration

require './dhcp-dns-lib.pl';
&ReadParse();
&error_setup($text{'apply_err'});
$err = &apply_configuration();
if ($err) {
	&error($err);
	}
else {
	&redirect("");
	}

