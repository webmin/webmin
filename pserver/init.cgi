#!/usr/local/bin/perl
# init.cgi
# Create a new empty repository

require './pserver-lib.pl';
$access{'init'} || &error($text{'init_ecannot'});
&error_setup($text{'init_err'});

$cmd = "$cvs_path -d $config{'cvsroot'} init";
$out = `$cmd 2>&1 </dev/null`;
if ($?) {
	&error("<pre>$out</pre>");
	}
&redirect("");

