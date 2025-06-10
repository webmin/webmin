#!/usr/local/bin/perl
# Set the Usermin session cookie to be some other user

require './usermin-lib.pl';
&ReadParse();
$access{'sessions'} || &error($text{'switch_euser'});

($cookie, $url) = &switch_to_usermin_user($in{'user'});
print "Set-Cookie: $cookie\n";
&redirect($url);
&webmin_log("switch", undef, $in{'user'});

