#!/usr/local/bin/perl
# Output the certificate in PEM or PKCS12 format

require './webmin-lib.pl';
&ReadParse();

&get_miniserv_config(\%miniserv);

if ($ENV{'PATH_INFO'} =~ /\.p12$/) {
	# PKCS12 format
	$data = &cert_pkcs12_data($miniserv{'keyfile'}, $miniserv{'certfile'});
	$type = "application/x-pkcs12";
	}
else {
	# PEM format
	$data = &cert_pem_data($miniserv{'certfile'} || $miniserv{'keyfile'});
	$type = "text/plain";
	}
if ($data) {
	print "Content-type: $type\n\n";
	print $data;
	}
else {
	&error($text{'ssl_edownload'});
	}
