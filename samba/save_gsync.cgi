#!/usr/local/bin/perl
# save_gsync.cgi
# Save unix-samba group synchronisation options

require './samba-lib.pl';

$access{'maint_gsync'} || &error($text{'gsync_ecannot'});
&ReadParse();

&lock_file("$module_config_directory/config");
foreach $s ("add", "change", "delete", "type", "priv") {
	if ($in{$s}) { $config{"gsync_$s"} = $in{$s}; }
	else { delete($config{"gsync_$s"}); }
	}
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("gsync");
&redirect("");

