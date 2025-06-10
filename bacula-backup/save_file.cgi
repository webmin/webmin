#!/usr/local/bin/perl
# Update the FileDaemon section

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'file_err'});

$conf = &get_file_config();
$file = &find("FileDaemon", $conf);
$file || &error($text{'file_enone'});
$mems = $file->{'members'};
&lock_file($file->{'file'});

# Validate and store inputs
$in{'name'} =~ /^[a-z0-9\.\-\_]+$/ || &error($text{'file_ename'});
&save_directive($conf, $file, "Name", $in{'name'}, 1);

$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
	&error($text{'file_eport'});
&save_directive($conf, $file, "FDport", $in{'port'}, 1);

$in{'jobs'} =~ /^\d+$/ || &error($text{'file_ejobs'});
&save_directive($conf, $file, "Maximum Concurrent Jobs", $in{'jobs'}, 1);

-d $in{'dir'} || &error($text{'file_edir'});
&save_directive($conf, $file, "WorkingDirectory", $in{'dir'}, 1);

# Validate and store TLS inputs
&parse_tls_directives($conf, $file, 1);

&flush_file_lines();
&unlock_file($file->{'file'});
&auto_apply_configuration();
&webmin_log("file");
&redirect("");

