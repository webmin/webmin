#!/usr/local/bin/perl
# change_startpage.cgi
# Change startpage settings

require './webmin-lib.pl';
&ReadParse();
&lock_file("$config_directory/config");
if ($in{'nocols_def'}) {
	delete($gconfig{'nocols'});
	}
else {
	$in{'nocols'} =~ /^\d+$/ ||
		&error(&text('startpage_ecols', $in{'nocols'}));
	$gconfig{'nocols'} = $in{'nocols'};
	}
$gconfig{'notabs'} = $in{'notabs'};
$gconfig{'gotoone'} = $in{'gotoone'};
$gconfig{'deftab'} = $in{'deftab'};
$gconfig{'nohostname'} = $in{'nohostname'};
$gconfig{'gotomodule'} = $in{'gotomodule'};
$gconfig{'nowebminup'} = !$in{'webminup'};
$gconfig{'nomoduleup'} = !$in{'moduleup'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log("startpage", undef, undef, \%in);
&redirect("");

