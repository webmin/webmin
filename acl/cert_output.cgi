#!/usr/local/bin/perl
# cert_issue.cgi

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';    ## no critic
our (%in, %text, %config, %access);
$access{'cert'} || &error($text{'cert_ecannot'});

&ReadParse();
my $file = &pending_certificate_file();
&lock_file($file);
my $cert = &read_file_contents($file);
defined($cert) && length($cert) || &error($text{'cert_etempdir'});
&unlink_file($file);
&unlock_file($file);
print "Content-type: application/x-x509-user-cert\n\n";
print $cert;
