#!/usr/local/bin/perl
# gencsr.cgi
# Generates certificates signing requests (CSRs)

require './certmgr-lib.pl';
&ReadParse();
$access{'gencsr'} || &error($text{'ecannot'});
&header($text{'gencsr_title'}, "");

if ($in{'keysize'}==512){$checked[0]=" checked";}
elsif ($in{'keysize'}==2048){$checked[2]=" checked";}
else {$checked[1]=" checked";}  # Default keysize 1024
$in{'c'}=~tr/[a-z]/[A-Z]/;
if ($in{'submitted'} eq "generate") {
	if (!$in{'cn'}) { $error.=$text{'gencert_e_nocn'}."<br>\n"; }
	if ($in{'password'} ne $in{'confirm_password'}) {
		$error.=$text{'gencert_e_badpw'}."<br>\n";
		$in{'password'}="";
		$in{'confirm_password'}="";
	}
	if (!($in{'csrfile'} && $in{'keyfile'} )){
		$error.=$text{'gencsr_e_nofilename'}."<br>\n";
	}
	if (!$error) {
		&process();
		exit;
	}
}

if ($error) {
        print "<hr> <b>$text{'gencsr_error'}</b>\n<ul>\n";
        print "$error</ul>\n$text{'gencsr_pleasefix'}\n";
} else {
	if (!$in{'csrfile'}) { $in{'csrfile'}=$config{'ssl_csr_dir'}."/".
		$config{'csr_filename'}; }
	if (!$in{'keyfile'}) { $in{'keyfile'}=$config{'ssl_key_dir'}."/".
		$config{'key_filename'}; }
	if (!$in{'cn'}) { $in{'cn'}=&get_system_hostname(); }
	if (!$in{'o'}) { $in{'o'}=$config{'default_o'}; }
	if (!$in{'ou'}) { $in{'ou'}=$config{'default_ou'}; }
	if (!$in{'l'}) { $in{'l'}=$config{'default_l'}; }
	if (!$in{'st'}) { $in{'st'}=$config{'default_st'}; }
	if (!$in{'c'}) { $in{'c'}=$config{'default_c'}; }
	$in{'c'}=~tr/[a-z]/[A-Z]/;
	if (!$in{'emailAddress'}) { $in{'emailAddress'}=$config{'default_email'}; }
}

print &ui_hr();
&print_cert_form("gencsr");
print &ui_hr();
&footer("", $text{'index_return'});

sub process{
	$conffilename=&tempname();
	$outfile=&tempname();
	if (((-e $in{'csrfile'})||(-e $in{'keyfile'}))&&($in{'overwrite'} ne "yes")) {
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
				-out $in{'csrfile'} -config $conffilename >$outfile 2>&1"))) {
		$error="$e_genfailed: $!";
	} else {
		close(OPENSSL);
		open(ERROR,"<$outfile");
		while(<ERROR>){$out.=$_;}
		close(ERROR);
		if (!((-e $in{'csrfile'})&&(-e $in{'keyfile'}))) { 
			$error=$out;
		} else {
			$error=0;
			chmod(0400,$in{'keyfile'});
		}
	}
	unlink($outfile);
	unlink($conffilename);
	print &ui_hr();
	if ($error){ print "<b>$text{'gencsr_e_genfailed'}</b>\n<pre>$error</pre>\n<hr>\n";}
	else {
		print "<b>$text{'gencsr_genworked'}</b>\n<pre>$out</pre>\n";
		$url="\"view.cgi?csrfile=".&my_urlize($in{'csrfile'}).'"';
		print "<b>$text{'gencsr_saved_csr'} <a href=$url>$in{'csrfile'}</a></b><br>\n";
		$url="\"view.cgi?keyfile=".&my_urlize($in{'keyfile'}).'"';
		print "<b>$text{'gencert_saved_key'} <a href=$url>$in{'keyfile'}</a></b><br>\n";
	}
	print &ui_hr();
	&footer("", $text{'index_return'});
}

sub overwriteprompt{
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
	
	print "<table>\n<tr valign=top>";
	if (-e $in{'csrfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} req -in $in{'csrfile'} -text -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="\"view.cgi?csrfile=".&my_urlize($in{'csrfile'}).'"';
		print "<td><table border><tr $tb><td align=center><b><a href=$url>$in{'csrfile'}</a></b></td> </tr>\n<tr $cb> <td>\n";
		if (!$buffer1) { print $text{'e_file'};}
		else { &print_cert_info(0,$buffer1); }
		print "</td></tr></table></td>\n";
	}
	if (-e $in{'keyfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} rsa -in $in{'keyfile'} -text -noout|");
		while(<OPENSSL>){ $buffer.=$_; }
		close(OPENSSL);
		$url="\"view.cgi?keyfile=".&my_urlize($in{'keyfile'}).'"';
		print "<td><table border><tr $tb> <td align=center><b><a href=$url>$in{'keyfile'}</a></b></td> </tr>\n<tr $cb> <td>\n";
		if (!$buffer) { print $text{'e_file'};}
		else { &print_key_info(0,$buffer); }
		print "</td></tr></table></td>\n";
	}
	print "</tr></table>\n";
	print "$text{'gencsr_moreinfo'}";
	print "<hr>\n$text{'gencsr_overwrite'}\n<p>\n";
	
	print "<form action=gencsr.cgi method=post>\n";
	foreach $key (keys %in) {
		print "<input name=\"$key\" type=hidden value=\"$in{$key}\">\n";
	}
	print "<input name=overwrite value=\"yes\" type=hidden>\n";
	print "<input type=submit value=\"$text{'continue'}\"></form>\n";
}
