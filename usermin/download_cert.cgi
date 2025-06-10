#!/usr/local/bin/perl
# Output the certificate in PEM or PKCS12 format

require './usermin-lib.pl';
&ReadParse();

&get_usermin_miniserv_config(\%miniserv);

if ($ENV{'PATH_INFO'} =~ /\.p12$/) {
	# PKCS12 format
	$data = &webmin::cert_pkcs12_data($miniserv{'keyfile'},
					  $miniserv{'certfile'});
	$type = "application/x-pkcs12";
	}
else {
	# PEM format
	$data = &webmin::cert_pem_data($miniserv{'certfile'} ||
				       $miniserv{'keyfile'});
	$type = "text/plain";
	}
if ($data) {
	print "Content-type: $type\n\n";
	print $data;
	}
else {
	&error($text{'ssl_edownload'});
	}
