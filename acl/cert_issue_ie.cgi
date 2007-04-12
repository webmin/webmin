#!/usr/local/bin/perl
# cert_issue_ie.cgi

require './acl-lib.pl';
&ReadParse();

&error_setup($text{'cert_err'});
&get_miniserv_config(\%miniserv);

# Save certificate request to a file
$req = $in{'data'};
$req =~ s/\r|\n//g;
$temp = &transname();
open(TEMP, ">$temp");
print TEMP "-----BEGIN CERTIFICATE REQUEST-----\n";
$result = 1;
while($result) {
    $result = substr($req, 0, 72);
    if($result) {
	print TEMP "$result\n";
	$req = substr($req, 72);
    }
}
print TEMP "-----END CERTIFICATE REQUEST-----\n";
close(TEMP);

# Call the openssl CA command to process the request
$temp2 = &transname();
$cmd = &get_ssleay();
$out = &backquote_logged("yes | $cmd ca -in $temp -out $temp2 -config $module_config_directory/openssl.cnf -days 1095 2>&1");
if ($?) {
	unlink($temp);
	&error("<pre>$out</pre>");
	}
unlink($temp);

# Create CRL if needed
$crl = "$module_config_directory/crl.pem";
if (!-r $crl_file) {
	$out = &backquote_logged("$config{'ssleay'} ca -gencrl -out $crl -config $module_config_directory/openssl.cnf 2>&1");
	if ($?) {
		&error("<pre>$out</pre>");
		}
	}

# Call the openssl crl2pkcs7 command to add to the CRL
$temp3 = &transname();
$out = &backquote_logged("$config{'ssleay'} crl2pkcs7 -certfile $temp2 -in $crl -out $temp3 2>&1");
if ($?) {
	unlink($temp2);
	&error("<pre>$out</pre>");
	}
unlink($temp2);
open(OUT, $temp3);
while(<OUT>) {
	s/\r|\n//g;
	if (/BEGIN PKCS7/) {
		$started++;
		}
	elsif (/END PKCS7/) {
		last;
		}
	elsif ($started) {
		$certificate .= $_;
		}
	}
close(OUT);
unlink($temp3);

# Output HTML for IE to install the new cert
$certdone = &text('cert_done', $in{'commonName'});
&ui_print_header(undef, $text{'cert_title'}, "");
print <<EOF;
<OBJECT classid="clsid:127698e4-e730-4e5c-a2b1-21490a70c8a1" sXEnrollVersion="5,131,3659,0" id=Enroll>
</OBJECT>

    <SCRIPT type="text/vbscript">
      sub CertAcceptSub()

	on error resume next

        Enroll.MyStoreFlags=&H10000
        Enroll.RequestStoreFlags=&H10000
        Enroll.acceptPKCS7(document.resultData.result.value)
        if err.Number <> 0 then
           msgbox "Error: Could not insert the PKCS7 envelope"
	else
	   msgbox "Installed certificate OK"
        end if
      end sub
    </SCRIPT>

    <form name="resultData">
      <input type="hidden" name="result" value="$certificate">

      <p>$certdone<p>
      <input type=hidden name=storeflags value="&H10000">
      <input type="button" name="accept" value="$text{'cert_install'}"
             onClick="CertAcceptSub" language="vbscript">

    </form>
EOF

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

