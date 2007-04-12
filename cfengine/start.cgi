#!/usr/local/bin/perl
# start.cgi
# Start the configuration engine daemon

require './cfengine-lib.pl';
&error_setup($text{'start_err'});
if ($config{'start_cmd'}) {
	$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
	}
else {
	$ENV{'CFINPUTS'} = $config{'cfengine_dir'};
	$out = &backquote_logged("$config{'cfd'} 2>&1 </dev/null");
	}
&error("<pre>$out</pre>") if ($out =~ /error|failed/ || $?);
&webmin_log("start");
&redirect("edit_cfd.cgi");

