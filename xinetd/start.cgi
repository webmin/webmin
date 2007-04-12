#!/usr/local/bin/perl
# start.cgi
# Start the xinetd server

require './xinetd-lib.pl';
&ReadParse();
&error_setup($text{'start_err'});
$out = &backquote_logged("$config{'start_cmd'} 2>&1");
&error(&text('start_estart', $config{'start_cmd'}, $out)) if ($?);
&webmin_log("start");
&redirect("");

