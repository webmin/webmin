#!/usr/local/bin/perl
# Just redirect to either the software module or update page

require './package-updates-lib.pl';
&ReadParse();

if ($in{'software'}) {
	&redirect("../software/edit_pack.cgi?package=".&urlize($in{'name'}).
		  "&version=".&urlize($in{'version'}));
	}
else {
	&redirect("update.cgi?u=".&urlize($in{'name'}."/".$in{'system'}).
		  "&all=$in{'all'}&mode=$in{'mode'}");
	}

