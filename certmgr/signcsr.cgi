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
        print &ui_hr()."<b>$text{'signcsr_error'}</b>\n<ul>\n";
        print "$error</ul>\n$text{'gencert_pleasefix'}\n";
}

print &ui_hr();
&print_sign_form("signcsr");
print &ui_hr();
&footer("", $text{'index_return'});

sub process{
	&foreign_require("webmin", "webmin-lib.pl");
	local %miniserv;
	&get_miniserv_config(\%miniserv);
	if (!$miniserv{'ca'}) {
		&webmin::setup_ca();
		}
	if ((-e $in{'signfile'})&&($in{'overwrite'} ne "yes")) {
		&overwriteprompt();
		print &ui_hr();
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
	print &ui_hr();
	if ($error){ print "<b>$text{'signcsr_e_signfailed'}</b>\n<pre>$error</pre>\n";}
	else {
		print "<b>$text{'signcsr_worked'}</b>\n<pre>$out</pre>\n";
		$url="view.cgi?certfile=".&my_urlize($in{'signfile'});
		print "<b>$text{'signcsr_saved_cert'}: ".&ui_link($url,$in{'signfile'})."</b>";
	}
	print &ui_hr();
	&footer("", $text{'index_return'});
}

sub overwriteprompt{
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
    my $rv = "";
    my $link = "";

	if (-e $in{'signfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'signfile'} -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="view.cgi?certfile=".&my_urlize($in{'signfile'});
        $link = &ui_link($url,$in{'signfile'});
        $rv = &ui_table_start($link, undef, 2);
        $rv .= &ui_table_row(undef, (!$buffer1 ? $text{'e_file'} : &show_cert_info(0,$buffer1) ) );
	}

    print "<br>";
    print $rv;
    print &ui_table_hr();
    print &ui_table_row(undef,$text{'gencert_moreinfo'});
    print &ui_table_row(undef,&ui_hr().$text{'gencert_overwrite'});
    $rv = &ui_form_start("signcsr.cgi", "post");
	foreach $key (keys %in) {
        $rv .= &ui_hidden($key,$in{$key});
	}
    $rv .= &ui_hidden("overwrite","yes");
    $rv .= &ui_submit($text{'continue'});
    $rv .= &ui_form_end();
    print &ui_table_row(undef,$rv);
    print &ui_table_end();

}
