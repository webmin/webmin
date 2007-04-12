#!/usr/local/bin/perl
# change_referers.cgi
# Change referer checking settings

require './webmin-lib.pl';
&ReadParse();

&lock_file("$config_directory/config");
$gconfig{'referer'} = $in{'referer'};
$gconfig{'referers'} = join(" ", split(/\s+/, $in{'referers'}));
$gconfig{'referers_none'} = !$in{'referers_none'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&webmin_log('referers', undef, undef, \%in);

&redirect("");

