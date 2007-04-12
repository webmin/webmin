#!/usr/local/bin/perl
# save_zonedef.cgi
# Save zone defaults

require './dns-lib.pl';
&ReadParse();
$whatfailed = "Failed to save zone defaults";
%access = &get_module_acl();
$access{'defaults'} || &error("You cannot edit zone defaults");

&lock_file("$module_config_directory/zonedef");
$in{'refresh'} =~ /^\S+$/ || &error("Invalid refresh time");
$in{'retry'} =~ /^\S+$/ || &error("Invalid transfer retry time");
$in{'expiry'} =~ /^\S+$/ || &error("Invalid expiry time");
$in{'minimum'} =~ /^\S+$/ || &error("Invalid default time-to-live");
%zonedef = ( 'refresh', $in{'refresh'},
	     'retry', $in{'retry'},
	     'expiry', $in{'expiry'},
	     'minimum', $in{'minimum'} );
&save_zone_defaults(\%zonedef);
&unlock_file("$module_config_directory/zonedef");
&webmin_log("zonedef", undef, undef, \%in);
&redirect("");

