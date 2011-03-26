#!/usr/bin/perl
# apply.pl
# Apply the firewall configuration

$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
$no_acl_check++;
if ($0 =~ /^(.*\/)[^\/]+$/) {
        chdir($1);
        }
require './itsecur-lib.pl';
$module_name eq 'itsecur-firewall' || die "Command must be run with full path";

print "$text{'apply_doing'}\n";
&enable_routing();
$err = &apply_rules();
if ($err) {
	print &text('apply_failed', $err),"\n";
	exit(1);
	}
else {
	print "$text{'apply_done'}\n";
	exit(0);
	}

