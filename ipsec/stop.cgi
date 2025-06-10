#!/usr/local/bin/perl
# stop.cgi
# Stop the IPsec server

require './ipsec-lib.pl';
&error_setup($text{'stop_err'});
$out = &backquote_logged("$config{'stop_cmd'} 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
&webmin_log("stop");
&redirect("");

