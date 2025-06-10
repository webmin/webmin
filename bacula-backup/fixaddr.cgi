#!/usr/local/bin/perl
# Update the host in bconsole.conf to match this system

require './bacula-backup-lib.pl';

&lock_file($bconsole_conf_file);
$conconf = &get_bconsole_config();
$condir = &find("Director", $conconf);
$addr = &get_system_hostname();
if (!&to_ipaddress($addr) && !&to_ip6address($addr)) {
	$addr = "localhost";
	}
&save_directive($conconf, $condir, "Address", $addr, 1);
&flush_file_lines();
&unlock_file($bconsole_conf_file);

&webmin_log("fixaddr");
&redirect("");

