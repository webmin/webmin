#!/usr/local/bin/perl
# Disable some boot-time action

package init;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/delete-boot.pl";
require './init-lib.pl';
$< == 0 || die "$0 must be run as root";

@ARGV == 1 ||
	die "usage: delete-boot.pl <name>";

&disable_at_boot(@ARGV);
