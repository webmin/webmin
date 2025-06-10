#!/usr/local/bin/perl
require './webmin-lib.pl';
&ReadParse();

&lock_file("$config_directory/webmin.cats");
foreach $module (keys %in){
	my %minfo = &get_module_info($module);
	next if (!%minfo);
	if ($minfo{'realcategory'} ne $in{$module}) {
		$cats{$module} = $in{$module};
		}
	}
&write_file("$config_directory/webmin.cats", \%cats);
&unlock_file("$config_directory/webmin.cats");
&webmin_log("assignment", undef, undef, \%in);
&flush_webmin_caches();

&redirect("index.cgi?refresh=1");
