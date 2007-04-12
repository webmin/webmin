#!/usr/local/bin/perl
# logout.cgi
# Cancel the username and password cookie for a server

require './servers-lib.pl';
&ReadParse();
print "Set-Cookie: $in{'id'}=; path=/";
if (uc($ENV{'HTTPS'}) eq 'ON') {
	print "; secure";
	}
print "\n";
&redirect("");

