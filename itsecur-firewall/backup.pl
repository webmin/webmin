#!/usr/bin/perl
# Do a backup on schedule

$no_acl_check++;
require './itsecur-lib.pl';

$file = $config{'backup_dest'};
if (-d $file) {
	$file .= "/firewall.zip";
	}
@what = split(/\s+/, $config{'backup_what'});
$pass = $config{'backup_pass'};

if ($file) {
	&backup_firewall(\@what, $file, $pass);
	}
