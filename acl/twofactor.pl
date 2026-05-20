#!/usr/local/bin/perl
# Validate the OTP for some user

use strict;
use warnings;
no warnings 'once';
our $module_name;
$main::no_acl_check = 1;
$main::no_referers_check = 1;
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
        chdir($1);
        }
require './acl-lib.pl';    ## no critic
$module_name eq 'acl' || die "Command must be run with full path";

# Check command-line args
@ARGV == 5 || die "Usage: $0 user provider id token api-key";
my ($user, $provider, $id, $token, $apikey) = @ARGV;

# Call the provider validation function
&foreign_require("webmin");
my $method = "validate_twofactor_".$provider;
my $code = webmin->can($method)
	or die "Unknown twofactor provider: $provider\n";
my $err = $code->($id, $token, $apikey);
if ($err) {
	$err =~ s/\r|\n/ /g;
	print $err,"\n";
	exit(1);
	}
else {
	exit(0);
	}
