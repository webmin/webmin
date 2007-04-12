#!/usr/local/bin/perl
# save_sync.cgi
# Save unix-postgresql synchronization options

require './postgresql-lib.pl';
&ReadParse();

$config{'sync_create'} = $in{'sync_create'};
$config{'sync_modify'} = $in{'sync_modify'};
$config{'sync_delete'} = $in{'sync_delete'};
&write_file("$module_config_directory/config", \%config);
&redirect("");

