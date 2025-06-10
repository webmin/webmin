#!/usr/local/bin/perl
# change_theme.cgi
# Change the current webmin theme

require './usermin-lib.pl';
$access{'themes'} || &error($text{'acl_ecannot'});
&ReadParse();

&lock_file($usermin_config);
&get_usermin_config(\%uconfig);
$uconfig{'theme'} = $in{'theme'};
&put_usermin_config(\%uconfig);
&unlock_file($usermin_config);

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
if ($in{'theme'}) {
	$miniserv{'preroot'} = $in{'theme'};
	}
else {
	delete($miniserv{'preroot'});
	}
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log('theme', undef, undef, \%in);

&redirect("");

