#!/usr/local/bin/perl
# setup_ca.cgi
# Setup a new certificate authority

require './webmin-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&ReadParse();
&error_setup($text{'ca_err'});
$in{'size_def'} || $in{'size'} =~ /^\d+$/ || &error($text{'newkey_esize'});

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
&setup_ca(\%miniserv) if (!-r $miniserv{'ca'});
&lock_file($miniserv{'ca'});
$ctemp = &transname();
$ktemp = &transname();
$outtemp = &transname();
%aclconfig = &foreign_config('acl');
$size = $in{'size_def'} ? $default_key_size : $in{'size'};
$cmd = &acl::get_ssleay();
open(CA, "| $cmd req -newkey rsa:$size -x509 -nodes -out $ctemp -keyout $ktemp -config $config_directory/acl/openssl.cnf -days 1825 >$outtemp 2>&1");
print CA $in{'countryName'},"\n";
print CA $in{'stateOrProvinceName'},"\n";
print CA "\n";
print CA $in{'organizationName'},"\n";
print CA $in{'organizationalUnitName'},"\n";
print CA $in{'commonName'},"\n";
print CA $in{'emailAddress'},"\n";
close(CA);
$out = `cat $outtemp`;
unlink($outtemp);
if (!-r $ctemp || !-r $ktemp) {
	&error("<pre>$out</pre>");
	}
system("cat $ctemp $ktemp >$miniserv{'ca'}");
unlink($ctemp);
unlink($ktemp);
unlink("$config_directory/acl/crl.pem");
chmod(0700, $miniserv{'ca'});
&unlock_file($miniserv{'ca'});

&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&ui_print_header(undef, $text{'ca_title'}, "");
print "<p>$text{'ca_setupok'}<p>\n";
&ui_print_footer("", $text{'index_return'});
&restart_miniserv(1);
&webmin_log("setupca", undef, undef, \%in);

