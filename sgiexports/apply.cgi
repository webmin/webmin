#!/usr/local/bin/perl
# apply.cgi
# Apply the current exports configuration

require './sgiexports-lib.pl';
&error_setup($text{'apply_err'});
$out = &backquote_logged("$config{'apply_cmd'} </dev/null 2>&1");
if ($?) {
	&error($out);
	}
&webmin_log('apply');
&redirect("");
