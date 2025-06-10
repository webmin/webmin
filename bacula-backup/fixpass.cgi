#!/usr/local/bin/perl
# Update the password in bconsole.conf to match bacula-dir.conf

require './bacula-backup-lib.pl';

&lock_file($bconsole_conf_file);
$dirconf = &get_director_config();
$dirdir = &find("Director", $dirconf);
$conconf = &get_bconsole_config();
$condir = &find("Director", $conconf);
$dirpass = &find_value("Password", $dirdir->{'members'});
&save_directive($conconf, $condir, "Password", $dirpass, 1);
&flush_file_lines();
&unlock_file($bconsole_conf_file);

&webmin_log("fixpass");
&redirect("");

