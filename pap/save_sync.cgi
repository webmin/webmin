#!/usr/local/bin/perl
# save_sync.cgi
# Save unix-ppp synchronisation options

require './pap-lib.pl';
$access{'secrets'} || &error($text{'secrets_ecannot'});
$access{'sync'} || &error($text{'sync_ecannot'});
&ReadParse();

&lock_file("$module_config_directory/config");
foreach $s ("add", "change", "delete") {
	if ($in{$s}) { $config{"sync_$s"} = 1; }
	else { delete($config{"sync_$s"}); }
	}
$config{'sync_server'} = $in{'server'};
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("sync", undef, undef, \%in);
&redirect("");

