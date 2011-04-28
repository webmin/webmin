#!/usr/local/bin/perl
# logout.cgi
# Cancel the username and password cookie for a server

use strict;
use warnings;
require './servers-lib.pl';
&ReadParse();
our (%in);
print "Set-Cookie: $in{'id'}=; path=/";
if (uc($ENV{'HTTPS'}) eq 'ON') {
	print "; secure";
	}
print "\n";
&redirect("");

