#!/usr/local/bin/perl
# newkey.cgi
# Generate a new host key

require './ipsec-lib.pl';
&ReadParse();
&error_setup($text{'newkey_err'});
$in{'host'} =~ /^[a-z0-9\.\-]+$/i || &error($text{'newkey_ehost'});
($ipsec_version, $ipsec_program) = &get_ipsec_version(\$out);
if ($ipsec_program && lc($ipsec_program) eq "libreswan") {
	# Modern Libreswan stores host keys in its NSS database
	$out = &backquote_logged("$config{'ipsec'} newhostkey 2>&1");
	}
else {
	# Legacy implementations write the key to ipsec.secrets
	$out = &backquote_logged("$config{'ipsec'} newhostkey --output '$config{'secrets'}' --hostname '$in{'host'}' 2>&1");
	}
$? && &error("<pre>$out</pre>");
&webmin_log("newkey");
&redirect("");

