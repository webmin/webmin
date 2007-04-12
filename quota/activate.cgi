#!/usr/local/bin/perl
# activate.cgi
# Turn quotas on or off for some filesystem

require './quota-lib.pl';
&ReadParse();
&can_edit_filesys($in{'dir'}) && $access{'enable'} ||
	&error($text{'activate_eallow'});

if ($in{'active'} == 0) {
	# Turn on quotas
	$whatfailed = $text{'activate_eon'};
	if ($error = &quotaon($in{'dir'}, $in{'mode'})) {
		&error($error);
		}
	&webmin_log("activate", undef, $in{'dir'}, \%in);
	}
else {
	# Turn off quotas
	$whatfailed = $text{'activate_eoff'};
	if ($error = &quotaoff($in{'dir'}, $in{'mode'})) {
		&error($error);
		}
	&webmin_log("deactivate", undef, $in{'dir'}, \%in);
	}
&redirect("");

