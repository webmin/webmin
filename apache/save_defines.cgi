#!/usr/local/bin/perl
# save_defines.cgi
# Save defined run-time httpd parameters

require './apache-lib.pl';
$access{'global'}==1 || &error($text{'defines_ecannot'});
&lock_file("$module_config_directory/site");
&ReadParse();
$site{'defines'} = join(" ", split(/\s+/, $in{'defines'}));
&write_file("$module_config_directory/site", \%site);
&unlock_file("$module_config_directory/site");
&webmin_log("defines", undef, undef, \%in);
&redirect("index.cgi?mode=global");
