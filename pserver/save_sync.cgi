#!/usr/local/bin/perl
# save_sync.cgi
# Save unix-CVS synchronization options

require './pserver-lib.pl';
$access{'passwd'} || &error($text{'passwd_ecannot'});
&ReadParse();

if ($in{'sync_mode'} == 0) {
	delete($config{'sync_user'});
	}
else {
	defined(getpwnam($in{'sync_user'})) || &error($text{'save_eunix'});
	$config{'sync_user'} = $in{'sync_user'};
	}
$config{'sync_create'} = $in{'sync_create'};
$config{'sync_modify'} = $in{'sync_modify'};
$config{'sync_delete'} = $in{'sync_delete'};
&write_file("$module_config_directory/config", \%config);
&redirect("");

