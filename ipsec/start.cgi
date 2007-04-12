#!/usr/local/bin/perl
# start.cgi
# Start the IPsec server

require './ipsec-lib.pl';
&error_setup($text{'start_err'});
&before_start();
$out = &backquote_logged("$config{'start_cmd'} 2>&1");
if ($?) {
	&error("<pre>$out</pre>");
	}
&after_start();
&webmin_log("start");
&redirect("");

