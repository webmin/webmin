#!/usr/local/bin/perl
# Redirect to either create_dir or create_limit

require './proftpd-lib.pl';
&ReadParse();
$args = "global=".&urlize($in{'global'})."&".
	"virt=".&urlize($in{'virt'})."&".
	"anon=".&urlize($in{'anon'});
if ($in{'mode'} == 0) {
	&redirect("create_dir.cgi?$args".
		  "&dir=".&urlize($in{'dir'}));
	}
else {
	&redirect("create_limit.cgi?$args".
		  "&cmd=".&urlize($in{'cmd'}));
	}
