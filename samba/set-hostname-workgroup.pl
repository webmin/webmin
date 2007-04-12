#!/usr/local/bin/perl
# Set the global hostname and workgroup options

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
chop($pwd = `pwd`);
$0 = "$pwd/set-hostname-workgroup.pl";
require './samba-lib.pl';
$< == 0 || die "set-hostname-workgroup.pl must be run as root";

@ARGV == 2 || die "usage: set-hostname-workgroup.pl <hostname> <workgroup>";
$ARGV[0] =~ /^[a-z0-9\.\-\_]+$/i || die "Hostname can only contain letters and numbers";
$ARGV[1] =~ /^[a-z0-9\.\-\_]+$/i || die "Workgroup can only contain letters and numbers";
&get_share("global");
&setval("netbios name", $ARGV[0]);
&setval("workgroup", $ARGV[1]);
&modify_share("global", "global");

