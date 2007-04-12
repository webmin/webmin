#!/usr/local/bin/perl
# newkey.cgi
# Generate a new host key

require './ipsec-lib.pl';
&ReadParse();
&error_setup($text{'newkey_err'});
$in{'host'} =~ /^[a-z0-9\.\-]+$/i || &error($text{'newkey_ehost'});
$out = &backquote_logged("$config{'ipsec'} newhostkey --output '$config{'secrets'}' --hostname '$in{'host'}' 2>&1");
$? && &error("<pre>$out</pre>");
&webmin_log("newkey");
&redirect("");

