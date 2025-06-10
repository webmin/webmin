#!/usr/local/bin/perl
# create_file.cgi
# Create the file for virtusers, domains, mailers or access_db

require './sendmail-lib.pl';
&ReadParse();
$conf = &get_sendmailcf();
if ($in{'mode'} eq 'virtusers') {
	require './virtusers-lib.pl';
	$access{'vmode'} || &error($text{'virtusers_ecannot'});
	$file = &virtusers_file($conf);
	($dbm, $dbmtype) = &virtusers_dbm($conf);
	$log = "virtuser";
	}
elsif ($in{'mode'} eq 'mailers') {
	require './mailers-lib.pl';
	$access{'mailers'} || &error($text{'mailers_ecannot'});
	$file = &mailers_file($conf);
	($dbm, $dbmtype) = &mailers_dbm($conf);
	$log = "mailer";
	}
elsif ($in{'mode'} eq 'generics') {
	require './generics-lib.pl';
	$access{'omode'} || &error($text{'generics_cannot'});
	$file = &generics_file($conf);
	($dbm, $dbmtype) = &generics_dbm($conf);
	$log = "generic";
	}
elsif ($in{'mode'} eq 'domains') {
	require './domain-lib.pl';
	$access{'domains'} || &error($text{'domains_ecannot'});
	$file = &domains_file($conf);
	($dbm, $dbmtype) = &domains_dbm($conf);
	$log = "domain";
	}
elsif ($in{'mode'} eq 'access') {
	require './access-lib.pl';
	$access{'access'} || &error($text{'access_ecannot'});
	$file = &access_file($conf);
	($dbm, $dbmtype) = &access_dbm($conf);
	$log = "access";
	}

&open_lock_tempfile(DFILE, ">>$file");
&close_tempfile(DFILE);
&system_logged("$config{'makemap_path'} $dbmtype $dbm <$file");
&webmin_log("manual", $log, $file);
&redirect("list_$in{'mode'}.cgi");

