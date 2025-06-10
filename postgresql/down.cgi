#!/usr/local/bin/perl
# down.cgi
# Move a hosts list entry down

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'host_ecannot'});

&lock_file($hba_conf_file);
@hosts = &get_hba_config();
$host = $hosts[$in{'idx'}];
&swap_hba($host, $hosts[$in{'idx'}+1]);
&unlock_file($hba_conf_file);
&restart_postgresql();
&webmin_log('move', 'hba',
		   $host->{'type'} eq 'local' ? 'local' :
		   $host->{'netmask'} eq '0.0.0.0' ? 'all' :
		   $host->{'netmask'} eq '255.255.255.255' ? $host->{'address'}:
		   "$host->{'address'}/$host->{'netmask'}", $host);
&redirect("list_hosts.cgi");

