#!/usr/local/bin/perl
# save_newmod.cgi
# Save the new module user settings

require './webmin-lib.pl';
&ReadParse();

if ($in{'newmod_def'}) {
	&save_newmodule_users(undef);
	}
else {
	&save_newmodule_users([ split(/\s+/, $in{'newmod'}) ]);
	}
&webmin_log("newmod");
&redirect("");

