#!/usr/local/bin/perl
# cert_issue.cgi

require './acl-lib.pl';
&ReadParse();

&error_setup($text{'cert_err'});
$in{'key'} || &error($text{'cert_ekey'});
&get_miniserv_config(\%miniserv);

# Create the new key
$temp1 = &transname();
$temp2 = &tempname();
open(IN, ">$temp1");
foreach $k ("emailAddress", "organizationalUnitName", "organizationName",
	    "stateOrProvinceName", "countryName", "commonName") {
	print IN "$k = $in{$k}\n";
	}
$in{'key'} =~ s/\s//g;
print IN "SPKAC = $in{'key'}\n";
close(IN);
$cmd = &get_ssleay();
$ssleay = &backquote_logged("$cmd ca -spkac $temp1 -out $temp2 -config $module_config_directory/openssl.cnf -days 1095 2>&1");
unlink($temp1);
if ($?) {
	&error("<pre>$ssleay</pre>");
	}
else {
	# Display status and redirect to actual cert file
	$| = 1;
	&ui_print_header(undef, $text{'cert_title'}, "");
	print "<p>",&text('cert_done', $in{'commonName'}),"<p>\n";
	print "<font size=+1>",&text('cert_pickup', "cert_output.cgi?file=$temp2"),"</font><p>\n";
	&ui_print_footer("", $text{'index_return'});

	# Update the miniserv users file
	&lock_file($miniserv{'userfile'});
	$lref = &read_file_lines($miniserv{'userfile'});
	foreach $l (@$lref) {
		@u = split(/:/, $l);
		if ($u[0] eq $base_remote_user) {
			$l = "$u[0]:$u[1]:$u[2]:/C=$in{'countryName'}/ST=$in{'stateOrProvinceName'}/O=$in{'organizationName'}/OU=$in{'organizationalUnitName'}/CN=$in{'commonName'}/Email=$in{'emailAddress'}";
			}
		}
	&flush_file_lines();
	&unlock_file($miniserv{'userfile'});

	sleep(1);
	&restart_miniserv();
	&webmin_log("cert", undef, $base_remote_user, \%in);
	}

