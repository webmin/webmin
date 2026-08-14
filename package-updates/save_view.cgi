#!/usr/local/bin/perl
# Just redirect to either the software module or update page

require './package-updates-lib.pl';
&ReadParse();

if ($in{'software'}) {
	&redirect("../software/edit_pack.cgi?package=".&urlize($in{'name'}).
		  "&version=".&urlize($in{'version'}));
	}
elsif ($in{'hold'} || $in{'unhold'}) {
	$action = $in{'hold'} ? "hold" : "unhold";
	&redirect("update.cgi?u=".&urlize($in{'name'}."/".$in{'system'}).
		  "&$action=1&mode=".&urlize($in{'mode'}));
	}
else {
	$mode = $in{'held'} ? "held" : $in{'mode'};
	&redirect("update.cgi?u=".&urlize($in{'name'}."/".$in{'system'}).
		  "&all=$in{'all'}&mode=".&urlize($mode));
	}

