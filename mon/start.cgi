#!/usr/local/bin/perl
# start.cgi
# Start the mon process

require './mon-lib.pl';
&error_setup($text{'start_err'});
$out = &backquote_logged("$config{'start_cmd'} 2>&1 </dev/null");
&error("<tt>$out</tt>") if ($?);
&redirect("");

