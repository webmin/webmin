#!/usr/local/bin/perl
# Validate the OTP for some user

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
        chdir($1);
        }
require './acl-lib.pl';
$module_name eq 'acl' || die "Command must be run with full path";

# Check command-line args
@ARGV == 4 || die "Usage: $0 user provider id token";
($user, $provider, $id, $token) = @ARGV;

# Call the provider validation function
&foreign_require("webmin");
$func = "webmin::validate_twofactor_".$provider;
$err = &$func($id, $token);
if ($err) {
	$err =~ s/\r|\n/ /g;
	print $err,"\n";
	exit(1);
	}
else {
	exit(0);
	}
