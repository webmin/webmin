#!/usr/local/bin/perl
# Redirect to either create_dir or create_limit

require './proftpd-lib.pl';
&ReadParse();
if ($in{'mode'} == 0) {
	&redirect("create_dir.cgi?global=".&urlize($in{'global'}).
		  "&dir=".&urlize($in{'dir'}));
	}
else {
	&redirect("create_limit.cgi?global=".&urlize($in{'global'}).
		  "&cmd=".&urlize($in{'cmd'}));
	}
