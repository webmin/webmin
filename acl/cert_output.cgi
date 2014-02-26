#!/usr/local/bin/perl
# cert_issue.cgi

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access);

&ReadParse();
my $tempdir = &tempname();
$tempdir =~ s/\/[^\/]+$//;
&is_under_directory($tempdir, $in{'file'}) ||
	&error($text{'cert_etempdir'});
print "Content-type: application/x-x509-user-cert\n\n";
print &read_file_contents($in{'file'});
&unlink_file($in{'file'});

