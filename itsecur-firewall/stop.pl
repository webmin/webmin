#!/usr/bin/perl
# stop.pl
# Stop the firewall

$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
$no_acl_check++;
if ($0 =~ /^(.*\/)[^\/]+$/) {
        chdir($1);
        }
require './itsecur-lib.pl';
$module_name eq 'itsecur-firewall' || die "Command must be run with full path";

print "$text{'stop_doing'}\n";
$err = &stop_rules();
if ($err) {
	print &text('stop_failed', $err),"\n";
	exit(1);
	}
else {
	print "$text{'stop_done'}\n";
	&disable_routing();
	exit(0);
	}

