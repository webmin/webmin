#!/usr/local/bin/perl
# apply.cgi
# Apply the current init config

require './inittab-lib.pl';
&error_setup($text{'apply_err'});
$out = &backquote_logged("$config{'telinit'} q 2>&1 </dev/null");
&error("<tt>$out</tt>") if ($?);
&webmin_log("apply");
&redirect("");

