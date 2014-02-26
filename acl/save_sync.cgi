#!/usr/local/bin/perl
# save_sync.cgi
# Save unix/webmin user synchronization

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $module_config_directory);
&ReadParse();
$access{'sync'} && $access{'create'} && $access{'delete'} ||
	&error($text{'sync_ecannot'});
&lock_file("$module_config_directory/config");
$config{'sync_create'} = $in{'create'};
$config{'sync_delete'} = $in{'delete'};
$config{'sync_unix'} = $in{'unix'};
$config{'sync_group'} = $in{'group'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("sync");
&redirect("");

