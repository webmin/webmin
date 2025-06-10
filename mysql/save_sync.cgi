#!/usr/local/bin/perl
# save_sync.cgi
# Save unix-mysql synchronization options

require './mysql-lib.pl';
&ReadParse();

$config{'sync_create'} = $in{'sync_create'};
$config{'sync_modify'} = $in{'sync_modify'};
$config{'sync_delete'} = $in{'sync_delete'};
$config{'sync_privs'} = join(" ", split(/\0/, $in{'sync_privs'}));
$config{'sync_host'} = $in{'host_def'} ? undef : $in{'host'};
&write_file("$module_config_directory/config", \%config);
&redirect("");

