#!/usr/bin/perl
# Set up remote logging, creating a webmin server if needed

require './itsecur-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&can_edit_error("remote");
&ReadParse();

# Validate inputs
&error_setup($text{'remote_err'});
if (!$in{'host_def'}) {
	gethostbyname($in{'host'}) || &error($text{'remote_ehost'});
	$in{'user'} || &error($text{'remote_euser'});
	$server = &save_remote($in{'host'}, $in{'port'},
			       $in{'user'}, $in{'pass'}, 1, 1);
	}
else {
	# Just stop logging
	&save_remote(undef, undef, undef, undef, 0, 1);
	}
&webmin_log("remote");
&redirect("");


