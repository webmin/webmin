#!/usr/local/bin/perl
# change_referers.cgi
# Change referer checking settings

require './usermin-lib.pl';
&ReadParse();

&get_usermin_config(\%ugconfig);
&lock_file($usermin_config);
$ugconfig{'referer'} = $in{'referer'};
$ugconfig{'referers'} = join(" ", split(/\s+/, $in{'referers'}));
$ugconfig{'referers_none'} = !$in{'referers_none'};
&put_usermin_config(\%ugconfig);
&unlock_file($usermin_config);
&webmin_log('referers', undef, undef, \%in);

&redirect("");

