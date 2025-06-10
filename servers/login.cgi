#!/usr/local/bin/perl
# login.cgi
# Store the username and password for a server in a cookie

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%in);
&ReadParse();
my $enc = &encode_base64($in{'user'}.":".$in{'pass'});
$enc =~ s/\r|\n//g;
print "Set-Cookie: $in{'id'}=$enc; path=/";
if (uc($ENV{'HTTPS'}) eq 'ON') {
	print "; secure";
	}
print "\n";
&redirect("link.cgi/$in{'id'}/");

