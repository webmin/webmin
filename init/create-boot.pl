#!/usr/local/bin/perl
# Creates some boot-time action

package init;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/create-boot.pl";
require './init-lib.pl';
$< == 0 || die "$0 must be run as root";

@ARGV >= 1 && @ARGV <= 4 ||
	die "usage: create-boot.pl <name> [desc] [start-code] [stop-code]";

&enable_at_boot(@ARGV);
