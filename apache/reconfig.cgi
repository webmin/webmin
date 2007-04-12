#!/usr/local/bin/perl
# reconfig.cgi
# Save apache configuration

require './apache-lib.pl';
$access{'global'}==1 || &error($text{'reconfig_ecannot'});
&ReadParse();

foreach $m (split(/\0/, $in{'mods'})) {
	push(@mods, "$m/$in{'ver'}");
	}
&lock_file($site_file);
&read_file($site_file, \%site);
$site{'size'} = $in{'size'};
$site{'modules'} = join(' ', @mods);
$site{'webmin'} = &get_webmin_version();
&write_file($site_file, \%site);
chmod(0644, $site_file);
&unlock_file($site_file);
&webmin_log("reconfig", undef, undef, \%in);
&redirect("");

