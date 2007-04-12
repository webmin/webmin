#!/usr/local/bin/perl
# Set a Samba share to read-only mode

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/readonly-share.pl";
require './samba-lib.pl';
$< == 0 || die "readwrite-share.pl must be run as root";

@ARGV || die "usage: readonly-share.pl <share> ...";
foreach $s (@ARGV) {
	&get_share($s);
	&setval("writable", "no");
	&modify_share($s, $s);
	}
