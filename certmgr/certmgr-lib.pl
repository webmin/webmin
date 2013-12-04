# certmgr-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

@pages = ( "gencert", "gencsr", "signcsr", "import", "view", "manual" );

sub my_urlize{
	my $temp=$_[0];
	$temp=~s~([^/:.a-zA-Z0-9])~sprintf("%%%2x",ord($1))~eg;
	return($temp);
}

sub print_cert_form{
    my $form=$_[0];
    my $certfield;
    if ($form=~/^gen(.*)$/) {$certfield=$1."file";}
    print $text{'gencert_password_notice'};
    print &ui_hr();
    print &ui_form_start("$form.cgi", "post");
    print "<input type=hidden name=submitted value=generate>";
    print &ui_table_start($text{$form.'_header'}, undef, 2);
    print &ui_table_row($text{$form.'_'.$certfield}, &ui_textbox($certfield, $in{$certfield}, 40));
    print &ui_table_row($text{'keyfile'}, &ui_textbox("keyfile", $in{'keyfile'}, 40));
    if ($form eq "gencert") {
        print &ui_table_row($text{'keycertfile'}, &ui_textbox("keycertfile", $in{'keycertfile'}, 40));
    }
    print &ui_table_row($text{'password'}, &ui_password("password", $in{'password'}, 40));
    print &ui_table_row($text{'confirm_password'}, &ui_password("confirm_password", $in{'confirm_password'}, 40));
    print &ui_table_row($text{'keysize'},
                        &ui_oneradio("keysize", "512", "512", ( $checked[0] ? 1 : undef ) )." ".
                        &ui_oneradio("keysize", "1024", "1024", ( $checked[1] ? 1 : undef ) )." ".
                        &ui_oneradio("keysize", "2048", "2048", ( $checked[2] ? 1 : undef ) ) );
    if ($form eq "gencert") {
        print &ui_table_row($text{$form.'_days'}, &ui_textbox("days", $in{'days'}, 40));
    }
    print &ui_table_row($text{'cn'}, &ui_textbox("cn", $in{'cn'}, 40));
    print &ui_table_row($text{'o'}, &ui_textbox("o", $in{'o'}, 40));
    print &ui_table_row($text{'ou'}, &ui_textbox("ou", $in{'ou'}, 40));
    print &ui_table_row($text{'l'}, &ui_textbox("l", $in{'l'}, 40));
    print &ui_table_row($text{'st'}, &ui_textbox("st", $in{'st'}, 40));
    print &ui_table_row($text{'c'}, &ui_textbox("c", $in{'c'}, 40));
    print &ui_table_row($text{'emailAddress'}, &ui_textbox("emailAddress", $in{'emailAddress'}, 40));
    print &ui_table_row("&nbsp;",
        &ui_reset($text{'reset'})." ".&ui_submit($text{$form.'_generate'}) );
    print &ui_table_end();
    print &ui_form_end();
}

sub print_sign_form {
    my $form=$_[0];
    my $certfield;
    print $text{'signcsr_desc'};
    print &ui_hr();
    print &ui_form_start("$form.cgi", "post");
    print "<input type=hidden name=submitted value=sign>";
    print &ui_table_start($text{'signcsr_header'}, undef, 2);
    print &ui_table_row($text{'signcsr_csrfile'}, &ui_textbox("csrfile", $in{'csrfile'}, 40));
    print &ui_table_row($text{'signcsr_signfile'}, &ui_textbox("signfile", $in{'signfile'}, 40));
    print &ui_table_row($text{'signcsr_keyfile'}, &ui_textbox("keycertfile", $in{'keycertfile'}, 40));
    print &ui_table_row("<a onClick='window.open(\"/help.cgi/certmgr/signcsr_ca_pass\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300,resizable=yes\"); return false' href=\"/help.cgi/certmgr/signcsr_ca_pass\"><b>$text{'signcsr_ca_passphrase'}</b></a>", 
                    &ui_password("password", $in{'password'}, 40));
    print &ui_table_row($text{'signcsr_days'}, &ui_textbox("days", $in{'days'}, 40));
    print &ui_table_row("&nbsp;",
        &ui_reset($text{'reset'})." ".&ui_submit($text{'signcsr_generate'}) );
    print &ui_table_end();
    print &ui_form_end();
}

sub print_cert_info{
	my $full=$_[0];
	my $certdata=$_[1];
	my %issuer;
	my %subject;
	my @fields=('CN','O','OU','L','ST','C');
	my $field;
	foreach $field (@fields){
		if ($certdata=~/^\s*Issuer:.*?\s+$field=(.*?)(, [A-Z]{1,2}|\/\w+=|$)/m) { $issuer{$field}=$1; }
		if ($certdata=~/^\s*Subject:.*?\s+$field=(.*?)(, [A-Z]{1,2}|\/\w+=|$)/m) { $subject{$field}=$1; }
	}
	if (!($certdata=~/^\s*Issuer:/m)) { $text{'certmgrlib_issuer'}=""; }
	if ($certdata=~/^\s*Issuer:.*?\/Email=(\S*?)(,\s*|$)/m) { $issuer{'emailAddress'}=$1;}
	if ($certdata=~/^\s*Subject:.*?\/Email=(\S*?)(,\s*|$)/m) { $subject{'emailAddress'}=$1;}
	if ($certdata=~/^\s*Not\s*After\s*:\s*(.*?)\s*$/m) { $subject{'expires'}=$1;}
	if ($certdata=~/^\s*Not\s*Before\s*:\s*(.*?)\s*$/m) { $subject{'issued'}=$1;}
	if ($certdata=~/^\s*MD5\s*Fingerprint=(.*?)\s*$/m) { $subject{'md5fingerprint'}=$1;}
	if ($certdata=~/^\s*(\S*)\s*Public\s*Key:\s*\((.*?)\s*bit\)\s*$/m) { $subject{'keytype'}=$1; $subject{'keysize'}=$2;}
	if ($certdata=~/^\s*Modulus\s*\(\d*\s*bit\):\s*((([0-9a-fA-F]{2}:)*\s*)*[0-9a-fA-F]{2})/ms) { $subject{'modulus'}=$1; }
	if ($certdata=~/^\s*Exponent:\s*(.*?)\s*?$/m) { $subject{'exponent'}=$1; }
	if ($subject{'L'} && ($subject{'ST'} || $subject{'C'})) {$subject{'L'}.=',';} #Append commas
	if ($subject{'ST'} && $subject{'C'}) {$subject{'ST'}.=',';}                   #Append commas
	if ($issuer{'L'} && ($issuer{'ST'} || $issuer{'C'})) {$issuer{'L'}.=',';}     #Append commas
	if ($issuer{'ST'} && $issuer{'C'}) {$issuer{'ST'}.=',';}                      #Append commas
	$subject{'modulus'}=~s/$/<\/code><br>/msg;
	$subject{'modulus'}=~s/^/<code>/msg;
	$subject{'modulus'}=~s/\s+//msg;
	print "<table width=100%>\n";
	print "<tr><td width=50%><b>$text{'certmgrlib_subject'}</b></td><td width=50%><b>$text{'certmgrlib_issuer'}</b></td></tr>\n";
	print "<tr><td>$subject{'CN'}</td><td>$issuer{'CN'}</td></tr>\n";
	print "<tr><td>$subject{'O'}</td><td>$issuer{'O'}</td></tr>\n";
	print "<tr><td>$subject{'OU'}</td><td>$issuer{'OU'}</td></tr>\n";
	print "<tr><td>$subject{'L'} $subject{'ST'} $subject{'C'}</td><td>$issuer{'L'} $issuer{'ST'} $issuer{'C'}</td></tr>\n";
	print "<tr><td>$subject{'emailAddress'}</td><td>$issuer{'emailAddress'}</td></tr>\n";
	if ($subject{'issued'}){
		print "<tr><td colspan=2>$text{'issued_on'} $subject{'issued'}</td></tr>\n";
		print "<tr><td colspan=2>$text{'expires_on'} $subject{'expires'}</td></tr>\n";
	}
	if ($full){
		print "<tr><td>$text{'keysize'}</td><td>$subject{'keysize'}</td></tr>\n";
		print "<tr><td>$text{'keytype'}</td><td>$subject{'keytype'}</td></tr>\n";
	}
	if ($full){
		print "<tr><td>$text{'publicExponent'}</td><td>$subject{'exponent'}</td></tr>\n";
		print "<tr><td colspan=2>$text{'modulus'}:<br>$subject{'modulus'}</td></tr>\n";
	}
	if ($subject{'md5fingerprint'}){
		print "<tr><td colspan=2>$text{'md5fingerprint'}:<br>$subject{'md5fingerprint'}</td></tr>\n";
	}
	print "</table>\n";
}

sub print_key_info{
	my $full=$_[0];
	my $keydata=$_[1];
	my %key;
	my @fields=('modulus','privateExponent','prime1','prime2','exponent1','exponent2','coefficient');
	my $field;
	$keydata=~/^publicExponent:\s*(.*?)\s*?$/ms;
	$key{'publicExponent'}=$1;
	$keydata=~/^Private-Key:\s*\((\d*)\s*bit\)\s*?$/ms;
	$key{'keysize'}=$1;
	foreach $field (@fields){
		if ($keydata=~/^$field:\s*((([0-9a-fA-F]{2}:)*\s*)*[0-9a-fA-F]{2})/ms) { $key{$field}=$1; }
	}
	print "<table width=100%>\n";
	print "<tr><td ";
	if ($full) { print "valign=top align=right"; }
	print ">$text{'keysize'}:</td><td>$key{'keysize'}</td></tr>\n";
	splice(@fields,1,0,'publicExponent');
	if ($full) { foreach $field (@fields){
		$key{$field}=~s/$/<\/code><br>/msg;
		$key{$field}=~s/^/<code>/msg;
		$key{$field}=~s/\s+//msg;
		print "<tr><td valign=top align=right>$text{$field}:</td><td>$key{$field}</td></tr>\n";
	} }
	print "</table>\n";
}

sub pem_or_der{
	my $filename=$_[0];
	my $filetype=$_[1];
	my $format;
	my $cipher;
	my $flag;
	if ($filetype=~/^cert(ificate)?$/i){
		open(PEM_OR_DER,$filename)||return("$text{'certmgrlib_e_file_open'} $filename");
		while(<PEM_OR_DER>){ if (/^\s*-+BEGIN\s*CERTIFICATE-*\s*$/i) { $format="PEM" } }
		close(PEM_OR_DER);
		if (!$format) {$format="DER";}
		open(PEM_OR_DER,"$config{'openssl_cmd'} x509 -in $filename -inform $format -text|")||return($text{'certmgrlib_e_exec'});
		while (<PEM_OR_DER>){
			if (/^\s*Certificate:\s$/) { 
				close(PEM_OR_DER);
				return($format);
			}
		}
		close(PEM_OR_DER);
		return($text{'certmgrlib_e_cert'});
	}
	if ($filetype=~/^key$/i){
		open(PEM_OR_DER,$filename)||return("$text{'certmgrlib_e_file_open'} $filename");
		while(<PEM_OR_DER>){
			if (/^\s*-+BEGIN\s*RSA\s*PRIVATE\s*KEY-*\s*$/i) { $format="PEM" }
			if (/^\s*Proc-Type:\s*\d*,ENCRYPTED\s*$/) { $flag=1; }
			if (($flag)&&(/^DEK-Info:\s*(.*?),.*$/i)) { $cipher=$1 }
		}
		close(PEM_OR_DER);
		if ($cipher) { if (wantarray) {return(($format,$cipher));} return($format); }
		else {$cipher="none";}
		if (!$format) {$format="DER";}
		open(PEM_OR_DER,"$config{'openssl_cmd'} rsa -in $filename -inform $format -text|")||return($text{'certmgrlib_e_exec'});
		while (<PEM_OR_DER>){
			if (/^\s*Private-Key:\s(\d*\sbit)\s*$/) { 
				close(PEM_OR_DER);
				if (wantarray) {return(($format,$cipher));}
				return($format);
			}
		}
		close(PEM_OR_DER);
		return($text{'certmgrlib_e_key'});
	}
}

sub getfiles {
	my(@dirs,@files,$thisdir,$dir);
	$thisdir=$_[0];
	opendir(DIR, $thisdir);
	@dirs= sort grep { !/^[.]{1,2}$/ && -d "$thisdir/$_" } readdir(DIR);
	closedir(DIR);
	opendir(DIR,$thisdir);
	@files= sort grep { -f "$thisdir/$_" } readdir(DIR);
	closedir(DIR);
	foreach $dir (@dirs) {
		push(@files, grep { $_=$dir.'/'.$_ } &getfiles($thisdir."/".$dir));
	}
	return(@files);
}

1;
