#!/usr/local/bin/perl
# Output the certificate in PEM format

require './webmin-lib.pl';
&ReadParse();

&get_miniserv_config(\%miniserv);
$data = &cert_pem_data($miniserv{'certfile'} || $miniserv{'keyfile'});
if ($data) {
	print "Content-type: text/plain\n\n";
	print $data;
	}
else {
	&error($text{'ssl_edownload'});
	}
