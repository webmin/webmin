#!/usr/local/bin/perl
# save_sync.cgi
# Save options for the automatic setting up of SSH for new users

require './sshd-lib.pl';
&ReadParse();
&lock_file("$module_config_directory/config");
$config{'sync_create'} = $in{'create'};
$config{'sync_auth'} = $in{'auth'};
$config{'sync_pass'} = $in{'pass'};
$config{'sync_type'} = $in{'type'};
#$config{'sync_gnupg'} = $in{'gnupg'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&redirect("");
