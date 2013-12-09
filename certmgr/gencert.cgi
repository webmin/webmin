#!/usr/local/bin/perl
# gencert.cgi
# Generates self-signed certificates

require './certmgr-lib.pl';
&ReadParse();
$access{'gencert'} || &error($text{'ecannot'});
&header($text{'gencert_title'}, "");

if ($in{'keysize'}==512){$checked[0]=" checked";}
elsif ($in{'keysize'}==2048){$checked[2]=" checked";}
else {$checked[1]=" checked";}  # Default keysize 1024
$in{'c'}=~tr/[a-z]/[A-Z]/;
if ($in{'submitted'} eq "generate") {
	if (!$in{'cn'}) { $error.=$text{'gencert_e_nocn'}."<br>\n"; }
	if (!$in{'days'}) { $error.=$text{'gencert_e_nodays'}."<br>\n"; }
	if ($in{'password'} ne $in{'confirm_password'}) {
		$error.=$text{'gencert_e_badpw'}."<br>\n";
		$in{'password'}="";
		$in{'confirm_password'}="";
	}
	if (!($in{'certfile'} && $in{'keyfile'})){
		$error.=$text{'gencert_e_nofilename'}."<br>\n";
	}
	if (!$error) {
		&process();
		exit;
	}
} else {
	if (!$in{'certfile'}) { $in{'certfile'}=$config{'ssl_cert_dir'}."/".
		$config{'cert_filename'}; }
	if (!$in{'keyfile'}) { $in{'keyfile'}=$config{'ssl_key_dir'}."/".
		$config{'key_filename'}; }
	if (!$in{'keycertfile'}) { $in{'keycertfile'}=
		$config{'ssl_key_dir'}."/".$config{'key_cert_filename'};}
} 
if (!$in{'cn'}) { $in{'cn'}=&get_system_hostname(); }
if (!$in{'days'}) { $in{'days'}=$config{'default_days'}; }

if ($error) {
        print "<hr><b>$text{'gencert_error'}</b>\n<ul>\n";
        print "$error</ul>\n$text{'gencert_pleasefix'}\n";
}

print &ui_hr();
&print_cert_form("gencert");
print &ui_hr();
&footer("", $text{'index_return'});

sub process{
	$conffilename=&tempname();
	$outfile=&tempname();
	if (((-e $in{'certfile'})||(-e $in{'keyfile'})||(-e $in{'keycertfile'}))&&($in{'overwrite'} ne "yes")) {
		&overwriteprompt();
		print &ui_hr();
		&footer("", $text{'index_return'});
		exit;
	}
	open(CONF,">$conffilename");
	print CONF <<EOF;
[ req ]
 distinguished_name = req_dn
 prompt = no
[ req_dn ]
 CN = $in{'cn'}
EOF
        if ($in{'o'}) {print CONF " O = $in{'o'}\n";}
        if ($in{'ou'}) {print CONF " OU = $in{'ou'}\n";}
        if ($in{'l'}) {print CONF " L = $in{'l'}\n";}
        if ($in{'st'}) {print CONF " ST = $in{'st'}\n";}
        if ($in{'c'}) {print CONF " C = $in{'c'}\n";}
        if ($in{'emailAddress'}) {print CONF " emailAddress = $in{'emailAddress'}\n";}
        close(CONF);
	if ($in{'password'}){ $des="-passout pass:".quotemeta($in{'password'}); }
	else { $des="-nodes"; }
	if (!(open(OPENSSL,"|$config{'openssl_cmd'} req $des -newkey rsa:$in{'keysize'} -keyout $in{'keyfile'} -new \\
				-out $in{'certfile'} -config $conffilename -x509 -days $in{'days'} \\
				-outform pem >$outfile 2>&1"))) {
		$error="$text{'e_genfailed'}: $!";
	} else {
		close(OPENSSL);
		open(ERROR,"<$outfile");
		while(<ERROR>){$out.=$_;}
		close(ERROR);
		if (!((-e $in{'certfile'})&&(-e $in{'keyfile'}))) { 
			$error=$out;
		} else{
			$error=0;
			chmod(0400,$in{'keyfile'});
			if ($in{'keycertfile'}) {
				open(OUTFILE,">$in{'keycertfile'}");
				open(INFILE,"$in{'keyfile'}");
				while(<INFILE>) { print OUTFILE; }
				close(INFILE);
				open(INFILE,"$in{'certfile'}");
				while(<INFILE>) { print OUTFILE; }
				close(INFILE);
				close(OUTFILE);
				chmod(0400,$in{'keycertfile'});
			}
		}
	}
	unlink($outfile);
	unlink($conffilename);
	print &ui_hr();
	if ($error){ print "<b>$text{'gencert_e_genfailed'}</b>\n<pre>$error</pre>\n";}
	else {
		print "<b>$text{'gencert_genworked'}</b>\n<pre>$out</pre>\n";
		$url="view.cgi?certfile=".&my_urlize($in{'certfile'});
        print "<ul>";
		print "<li><b>$text{'gencert_saved_cert'}: ".&ui_link($url,$in{'certfile'})."</b></li>";
		$url="view.cgi?keyfile=".&my_urlize($in{'keyfile'});
		print "<li><b>$text{'gencert_saved_key'}: ".&ui_link($url,$in{'keyfile'})."</b></li>";
		$url="view.cgi?keycertfile=".&my_urlize($in{'keycertfile'});
		if (-e $in{'keycertfile'}) {
			print "<li><b>$text{'gencert_saved_keycert'}: ".&ui_link($url,$in{'keycertfile'})."</b></li>";
		}
        print "</ul>";
	}
	print &ui_hr();
	&footer("", $text{'index_return'});
}

sub overwriteprompt{
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
	my $rv = "";
    my $link = "";
	if (-e $in{'certfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'certfile'} -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="view.cgi?certfile=".&my_urlize($in{'certfile'});
        $link = &ui_link($url,$in{'certfile'});
        $rv = &ui_table_start($link, undef, 2);
        $rv .= &ui_table_row(undef, (!$buffer1 ? $text{'e_file'} : &show_cert_info(0,$buffer1) ) );
	}
	if (-e $in{'keyfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} rsa -in $in{'keyfile'} -text -noout|");
		while(<OPENSSL>){ $buffer.=$_; }
		close(OPENSSL);
		$url="view.cgi?keyfile=".&my_urlize($in{'keyfile'});
        $link = &ui_link($url,$in{'keyfile'});
        $rv = &ui_table_start($link, undef, 2);
        $rv .= &ui_table_row(undef, (!$buffer ? $text{'e_file'} : &show_key_info(0,$buffer) ) );
	}
	if (-e $in{'keycertfile'}) {
		undef($buffer);
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'keycertfile'} -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer2.=$_; }
		close(OPENSSL);
		open(OPENSSL,"$config{'openssl_cmd'} rsa -in $in{'keycertfile'} -text -noout|");
		while(<OPENSSL>){ $buffer.=$_; }
		close(OPENSSL);
		if ($buffer1 ne $buffer2) {
			$url="view.cgi?keycertfile=".&my_urlize($in{'keycertfile'});
            $link = &ui_link($url,$in{'keycertfile'});
            $rv = &ui_table_start($link, undef, 2);
            $rv .= &ui_table_row($text{'certificate'}, "<b>".$text{'key'}."</b>");
            $rv .= &ui_table_row(undef, (!$buffer2 ? $text{'e_file'} : &show_cert_info(0,$buffer2) ) );
            $rv .= &ui_table_row(undef, (!$buffer ? $text{'e_file'} : &show_key_info(0,$buffer) ) );
		}
	}

    print "<br>";
    print $rv;
    print &ui_table_hr();
    print &ui_table_row(undef,$text{'gencert_moreinfo'});
    print &ui_table_row(undef,&ui_hr().$text{'gencert_overwrite'});
    $rv = ui_form_start("gencert.cgi", "post");
	foreach $key (keys %in) {
        $rv .= &ui_hidden($key,$in{$key});
	}
    $rv .= &ui_hidden("overwrite","yes");
    $rv .= &ui_submit($text{'continue'});
    $rv .= &ui_form_end();
    print &ui_table_row(undef,$rv);
    print &ui_table_end();
}
