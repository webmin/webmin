#!/usr/local/bin/perl
# Update the Director section

require './bacula-backup-lib.pl';
&ReadParse();
&error_setup($text{'director_err'});

$conf = &get_director_config();
$director = &find("Director", $conf);
$director || &error($text{'director_enone'});
$mems = $director->{'members'};
&lock_file($director->{'file'});

# Validate and store inputs
$in{'name'} =~ /^[a-z0-9\.\-\_]+$/ || &error($text{'director_ename'});
&save_directive($conf, $director, "Name", $in{'name'}, 1);

$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
	&error($text{'director_eport'});
&save_directive($conf, $director, "DIRport", $in{'port'}, 1);

$in{'jobs'} =~ /^\d+$/ || &error($text{'director_ejobs'});
&save_directive($conf, $director, "Maximum Concurrent Jobs", $in{'jobs'}, 1);

&save_directive($conf, $director, "Messages", $in{'messages'} || undef, 1);

-d $in{'dir'} || &error($text{'director_edir'});
&save_directive($conf, $director, "WorkingDirectory", $in{'dir'}, 1);

# Validate and store TLS inputs
&parse_tls_directives($conf, $director, 1);

&flush_file_lines();
&unlock_file($director->{'file'});
&auto_apply_configuration();
&webmin_log("director");
&redirect("");

