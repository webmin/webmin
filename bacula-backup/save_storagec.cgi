#!/usr/local/bin/perl
# Update the Storage section

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'storagec_err'});

$conf = &get_storage_config();
$storagec = &find("Storage", $conf);
$storagec || &error($text{'storagec_enone'});
$mems = $storagec->{'members'};
&lock_file($storagec->{'file'});

# Validate and store inputs
$in{'name'} =~ /^[a-z0-9\.\-\_]+$/ || &error($text{'storagec_ename'});
&save_directive($conf, $storagec, "Name", $in{'name'}, 1);

$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
	&error($text{'storagec_eport'});
&save_directive($conf, $storagec, "SDport", $in{'port'}, 1);

$in{'jobs'} =~ /^\d+$/ || &error($text{'storagec_ejobs'});
&save_directive($conf, $storagec, "Maximum Concurrent Jobs", $in{'jobs'}, 1);

-d $in{'dir'} || &error($text{'storagec_edir'});
&save_directive($conf, $storagec, "WorkingDirectory", $in{'dir'}, 1);

# Validate and store TLS inputs
&parse_tls_directives($conf, $storagec, 1);

&flush_file_lines();
&unlock_file($storagec->{'file'});
&auto_apply_configuration();
&webmin_log("storagec");
&redirect("");

