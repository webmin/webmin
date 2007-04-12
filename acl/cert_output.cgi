#!/usr/local/bin/perl
# cert_issue.cgi

require './acl-lib.pl';
&ReadParse();
print "Content-type: application/x-x509-user-cert\n\n";
open(OUT, $in{'file'});
while(<OUT>) {
	print;
	}
close(OUT);
unlink($in{'file'});

