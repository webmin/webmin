#!/usr/local/bin/perl
# save_sync.cgi
# Update synchronization settings

require './htpasswd-file-lib.pl';
$access{'sync'} || &error($text{'sync_ecannot'});
&ReadParse();
&lock_file("$module_config_directory/config");
$config{'sync_create'} = $in{'create'};
$config{'sync_modify'} = $in{'modify'};
$config{'sync_delete'} = $in{'delete'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("sync");
&redirect("");

