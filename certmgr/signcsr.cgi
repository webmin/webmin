#!/usr/local/bin/perl
# signcsr.cgi
# Signs CSRs with a cert

require './certmgr-lib.pl';
$access{'signcsr'} || &error($text{'ecannot'});
&ReadParse();
&header($text{'signcsr_title'}, "");

if ($in{'submitted'} eq "sign") {
	if (!$in{'days'}) { $error.=$text{'gencert_e_nodays'}."<br>\n"; }
	if (!$in{'csrfile'}) {
		$error.=$text{'signcsr_e_nocsrfile'}."<br>\n";
	}
	if (!$in{'signfile'}) {
		$error.=$text{'signcsr_e_nosignfile'}."<br>\n";
	}
	if (!$in{'keyfile'} || !$in{'keycertfile'}) {
		$error.=$text{'signcsr_e_nokeyfile'}."<br>\n";
	}
	if (!$error) {
		&process();
		exit;
	}
} else {
	if (!$in{'csrfile'}) { $in{'csrfile'}=$config{'ssl_csr_dir'}."/".
		$config{'incsr_filename'}; }
	if (!$in{'signfile'}) { $in{'signfile'}=$config{'ssl_cert_dir'}."/".
		$config{'sign_filename'}; }
	if (!$in{'keyfile'}) { $in{'keyfile'}=$config{'cakey_path'}; }
	if (!$in{'keycertfile'}) { $in{'keycertfile'}=$config{'cacert_path'};}
	if (!$in{'days'}) { $in{'days'}=$config{'default_days'}; }
}

if ($error) {
        print "<hr> <b>$text{'signcsr_error'}</b>\n<ul>\n";
        print "$error</ul>\n$text{'gencert_pleasefix'}\n";
}

print "<hr>\n";
&print_sign_form("signcsr");
print "<hr>\n";
&footer("", $text{'index_return'});

sub process{
	&foreign_require("webmin", "webmin-lib.pl");
	&webmin::setup_ca();
	if ((-e $in{'signfile'})&&($in{'overwrite'} ne "yes")) {
		&overwriteprompt();
		print "<hr>\n";
		&footer("", $text{'index_return'});
		exit;
	}
	$tempdir = &tempname();
	mkdir($tempdir, 0700);
	if ($in{'password'}){ $des="-passin pass:".quotemeta($in{'password'}); }
	$out = `yes | $config{'openssl_cmd'} ca -in $in{'csrfile'} -out $in{'signfile'} -cert $in{'keycertfile'} -keyfile $in{'keyfile'} -outdir $tempdir -days $in{'days'} -config $config_directory/acl/openssl.cnf $des 2>&1`;

	system("rm -rf $tempdir");
	if (!-e $in{'csrfile'}) { 
		$error=$out;
	} else{
		$error=0;
		chmod(0400,$in{'signfile'});
	}
	print "<hr>\n";
	if ($error){ print "<b>$text{'signcsr_e_signfailed'}</b>\n<pre>$error</pre>\n<hr>\n";}
	else {
		print "<b>$text{'signcsr_worked'}</b>\n<pre>$out</pre>\n";
		$url="\"view.cgi?certfile=".&my_urlize($in{'signfile'}).'"';
		print "<b>$text{'signcsr_saved_cert'} <a href=$url>$in{'signfile'}</a></b><br>\n";
		print "<hr>\n";
	}
	&footer("", $text{'index_return'});
}

sub overwriteprompt{
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
	
	print "<table>\n<tr valign=top>";
	if (-e $in{'signfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'signfile'} -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="\"view.cgi?certfile=".&my_urlize($in{'signfile'}).'"';
		print "<td><table border><tr $tb><td align=center><b><a href=$url>$in{'signfile'}</a></b></td> </tr>\n<tr $cb> <td>\n";
		if (!$buffer1) { print $text{'e_file'};}
		else { &print_cert_info(0,$buffer1); }
		print "</td></tr></table></td>\n";
	}
	print "</tr></table>\n";
	print "$text{'gencert_moreinfo'}";
	print "<hr>\n$text{'gencert_overwrite'}\n<p>\n";
	
	print "<form action=signcsr.cgi method=post>\n";
	foreach $key (keys %in) {
		print "<input name=\"$key\" type=hidden value=\"$in{$key}\">\n";
	}
	print "<input name=overwrite value=\"yes\" type=hidden>\n";
	print "<input type=submit value=\"$text{'continue'}\"></form>\n";
}
