# certmgr-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

@pages = ( "gencert", "gencsr", "signcsr", "import", "view", "manual" );
$valign_middle = ["valign=middle","valign=middle"];

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
    print &ui_hidden("submitted","generate");
    print &ui_table_start($text{$form.'_header'}, undef, 2);
    print &ui_table_row($text{$form.'_'.$certfield}, &ui_textbox($certfield, $in{$certfield}, 40), undef, $valign_middle);
    print &ui_table_row($text{'keyfile'}, &ui_textbox("keyfile", $in{'keyfile'}, 40), undef, $valign_middle);
    if ($form eq "gencert") {
        print &ui_table_row($text{'keycertfile'}, &ui_textbox("keycertfile", $in{'keycertfile'}, 40), undef, $valign_middle);
    }
    print &ui_table_row($text{'password'}, &ui_password("password", $in{'password'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'confirm_password'}, &ui_password("confirm_password", $in{'confirm_password'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'keysize'},
                        &ui_oneradio("keysize", "512", "512", ( $checked[0] ? 1 : undef ) )." ".
                        &ui_oneradio("keysize", "1024", "1024", ( $checked[1] ? 1 : undef ) )." ".
                        &ui_oneradio("keysize", "2048", "2048", ( $checked[2] ? 1 : undef ) ), undef, $valign_middle);
    if ($form eq "gencert") {
        print &ui_table_row($text{$form.'_days'}, &ui_textbox("days", $in{'days'}, 40), undef, $valign_middle);
    }
    print &ui_table_row($text{'cn'}, &ui_textbox("cn", $in{'cn'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'o'}, &ui_textbox("o", $in{'o'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'ou'}, &ui_textbox("ou", $in{'ou'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'l'}, &ui_textbox("l", $in{'l'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'st'}, &ui_textbox("st", $in{'st'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'c'}, &ui_textbox("c", $in{'c'}, 40, undef, 2), undef, $valign_middle);
    print &ui_table_row($text{'emailAddress'}, &ui_textbox("emailAddress", $in{'emailAddress'}, 40), undef, $valign_middle);
    print &ui_table_row("&nbsp;",
        &ui_reset($text{'reset'})." ".&ui_submit($text{$form.'_generate'}), undef, $valign_middle);
    print &ui_table_end();
    print &ui_form_end();
}

sub print_sign_form {
    my $form=$_[0];
    my $certfield;
    print $text{'signcsr_desc'};
    print &ui_hr();
    print &ui_form_start("$form.cgi", "post");
    print &ui_hidden("submitted","sign");
    print &ui_table_start($text{'signcsr_header'}, undef, 2);
    print &ui_table_row($text{'signcsr_csrfile'}, &ui_textbox("csrfile", $in{'csrfile'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'signcsr_signfile'}, &ui_textbox("signfile", $in{'signfile'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'signcsr_keycertfile'}, &ui_textbox("cacertfile", $in{'cacertfile'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'signcsr_keyfile'}, &ui_textbox("cakeyfile", $in{'cakeyfile'}, 40), undef, $valign_middle);
    print &ui_table_row(&ui_link("/help.cgi/certmgr/signcsr_ca_pass",
                    "<b>$text{'signcsr_ca_passphrase'}</b>", undef,
                    "onClick='window.open(\"/help.cgi/certmgr/signcsr_ca_pass\", \"help\", \"toolbar=no,menubar=no,scrollbars=yes,width=400,height=300,resizable=yes\"); return false;'"), 
                    &ui_password("password", $in{'password'}, 40), undef, $valign_middle);
    print &ui_table_row($text{'signcsr_days'}, &ui_textbox("days", $in{'days'}, 40), undef, $valign_middle);
    print &ui_table_row("&nbsp;",
        &ui_reset($text{'reset'})." ".&ui_submit($text{'signcsr_generate'}), undef, $valign_middle);
    print &ui_table_end();
    print &ui_form_end();
}

sub show_cert_info {
	my $full=$_[0];
	my $certdata=$_[1];
	my %issuer;
	my %subject;
    my %v3ext;
    my $isreq=0;
    my @gr;
	my @fields=('CN','O','OU','L','ST','C');
	my $field;
    if ($certdata=~/^\s*Certificate\s+Request:.*$/mi) {$isreq=1;}
	foreach $field (@fields){
		if ($certdata=~/^\s*Issuer:.*?\s+$field=(.*?)(, [A-Z]{1,2}|\/\w+=|$)/m) { $issuer{$field}=$1; }
		if ($certdata=~/^\s*Subject:.*?\s+$field=(.*?)(, [A-Z]{1,2}|\/\w+=|$)/m) { $subject{$field}=$1; }
	}
	if (!($certdata=~/^\s*Issuer:/m)) { $text{'certmgrlib_issuer'}=""; }
	if ($certdata=~/^\s*Issuer:.*?\/Email=(\S*?)(,\s*|$)/m) { $issuer{'emailAddress'}=$1;}
	if ($certdata=~/^\s*Subject:.*?\/Email=(\S*?)(,\s*|$)/m) { $subject{'emailAddress'}=$1;}
	if ($certdata=~/^\s*Not\s*After\s*:\s*(.*?)\s*$/m) { $subject{'expires'}=$1;}
	if ($certdata=~/^\s*Not\s*Before\s*:\s*(.*?)\s*$/m) { $subject{'issued'}=$1;}
	if ($certdata=~/^\s*MD5\s+Fingerprint=(.*?)\s*$/m) { $subject{'md5fingerprint'}=$1;}
	if ($certdata=~/^\s*SHA1\s+Fingerprint=(.*?)\s*$/m) { $subject{'sha1fingerprint'}=$1;}
	if ($certdata=~/^\s*SHA256\s+Fingerprint=(.*?)\s*$/m) { $subject{'sha256fingerprint'}=$1;}
	if ($certdata=~/^\s*Public\s+Key\s+Algorithm:\s*(.*?)\s*$/mi) { $subject{'keytype'}=$1;}
	if ($certdata=~/^\s*Public-Key:\s*\(\s*(\S*?)\s*bit\s*\)\s*$/m) { $subject{'keysize'}=$1;}
	if ($certdata=~/^\s*Modulus:\s*((([0-9a-fA-F]{2}:)*\s*)*[0-9a-fA-F]{2})/ms) { $subject{'modulus'}=$1; }
	if ($certdata=~/^\s*Exponent:\s*(.*?)\s*?$/m) { $subject{'exponent'}=$1; }
	if ($certdata=~/^\s*X509v3 Subject Alternative Name:\s*(.*?)\s*?$/m) { $v3ext{'san'}=$1; }
	if ($certdata=~/^\s*Serial\s+Number:\s*((([0-9a-fA-F]{2}:)*\s*)*[0-9a-fA-F]{2})\s+/ms) { $subject{'serial'}=$1;}
    if (!$subject{'serial'}) {
        if ($certdata=~/^\s*Serial\s+Number:\s*([0-9]+)\s*\(/ms) { $subject{'serial'}=$1;}
    }
	if ($certdata=~/^\s*Signature\s+Algorithm:\s*(.*)$/mi) { $subject{'sigalgorithm'}=$1;}
	if ($subject{'L'} && ($subject{'ST'} || $subject{'C'})) {$subject{'L'}.=',';} #Append commas
	if ($subject{'ST'} && $subject{'C'}) {$subject{'ST'}.=',';}                   #Append commas
	if ($issuer{'L'} && ($issuer{'ST'} || $issuer{'C'})) {$issuer{'L'}.=',';}     #Append commas
	if ($issuer{'ST'} && $issuer{'C'}) {$issuer{'ST'}.=',';}                      #Append commas
	$subject{'modulus'}=~s/$/<\/code><br>/msg;
	$subject{'modulus'}=~s/^/<code>/msg;
	$subject{'modulus'}=~s/\s+//msg;
    
    push(@gr, '<span style="font-weight:bold;">'.$text{'certmgrlib_subject'}.'</span>');
    push(@gr, '');
    push(@gr, $text{'view_cn'});
    push(@gr, $subject{'CN'});
    if ($subject{'O'}) {
        push(@gr, $text{'view_o'});
        push(@gr, $subject{'O'});
    }
    if ($subject{'OU'}){
        push(@gr, $text{'view_ou'});
        push(@gr, $subject{'OU'});
    }
    if ($subject{'L'} || $subject{'ST'} || $subject{'C'}) {
        push(@gr, $text{'view_location'});
        push(@gr, $subject{'L'}.$subject{'ST'}.$subject{'C'});
    }
	if ($subject{'emailAddress'}){
        push(@gr, $text{'view_email'});
        push(@gr, $subject{'emailAddress'});
    }
    if ($v3ext{'san'}){
        push(@gr, "subjectAltName");
        push(@gr, $v3ext{'san'});
    }
	if ($subject{'issued'}){
        push(@gr, $text{'issued_on'});
        push(@gr, $subject{'issued'});
        push(@gr, $text{'expires_on'});
        push(@gr, $subject{'expires'});
	}
	if ($subject{'md5fingerprint'}){
        push(@gr, $text{'md5fingerprint'});
        push(@gr, $subject{'md5fingerprint'});
	}
	if ($subject{'sha1fingerprint'}){
        push(@gr, $text{'sha1fingerprint'});
        push(@gr, $subject{'sha1fingerprint'});
	}
	if ($subject{'sha256fingerprint'}){
        push(@gr, $text{'sha256fingerprint'});
        push(@gr, $subject{'sha256fingerprint'});
	}
    if ($full) {
        if ($subject{'serial'}) {
            push(@gr, $text{'view_serial'});
            push(@gr, $subject{'serial'});
        }
        if ($subject{'sigalgorithm'}) {
            push(@gr, $text{'view_sig_algorithm'});
            push(@gr, $subject{'sigalgorithm'});
        }
        push(@gr, $text{'keysize'});
        push(@gr, $subject{'keysize'});
        push(@gr, $text{'keytype'});
        push(@gr, $subject{'keytype'});
        push(@gr, $text{'publicExponent'});
        push(@gr, $subject{'exponent'});
        push(@gr, $text{'modulus'});
        push(@gr, $subject{'modulus'});
    }
    if (!$isreq) {
        push(@gr, '<br /><span style="font-weight:bold;">'.$text{'certmgrlib_issuer'}.'</span>');
        push(@gr, '');
        push(@gr, $text{'view_cn'});
        push(@gr, $issuer{'CN'});
        if ($issuer{'O'}) {
            push(@gr, $text{'view_o'});
            push(@gr, $issuer{'O'});
        }
        if ($issuer{'OU'}){
            push(@gr, $text{'view_ou'});
            push(@gr, $issuer{'OU'});
        }
        if ($issuer{'L'} || $issuer{'ST'} || $issuer{'C'}) {
            push(@gr, $text{'view_location'});
            push(@gr, $issuer{'L'}.$issuer{'ST'}.$issuer{'C'});
        }
    }
   return &ui_grid_table(\@gr, 2, undef, ['style="padding:0;"', 'style="padding:0 0 0.5% 3%;width:75%;"']);
}

sub show_key_info {
	my $full=$_[0];
	my $keydata=$_[1];
	my %key;
	my @fields=('modulus','privateExponent','prime1','prime2','exponent1','exponent2','coefficient');
	my $field;
    my $rv = "";
	$keydata=~/^publicExponent:\s*(.*?)\s*?$/ms;
	$key{'publicExponent'}=$1;
	$keydata=~/^Private-Key:\s*\((\d*)\s*bit\)\s*?$/ms;
	$key{'keysize'}=$1;
	foreach $field (@fields){
		if ($keydata=~/^$field:\s*((([0-9a-fA-F]{2}:)*\s*)*[0-9a-fA-F]{2})/ms) { $key{$field}=$1; }
	}
	$rv .= "<table width=100%>\n";
	$rv .= "<tr><td ";
	if ($full) { $rv .= "valign=top align=right"; }
	$rv .= ">$text{'keysize'}:</td><td>$key{'keysize'}</td></tr>\n";
	splice(@fields,1,0,'publicExponent');
	if ($full) { foreach $field (@fields){
		$key{$field}=~s/$/<\/code><br>/msg;
		$key{$field}=~s/^/<code>/msg;
		$key{$field}=~s/\s+//msg;
		$rv .= "<tr><td valign=top align=right>$text{$field}:</td><td>$key{$field}</td></tr>\n";
	} }
	$rv .= "</table>\n";
    return $rv;
}

sub show_crl_info {
	my $full=$_[0];
	my $crldata=$_[1];
	my %issuer;
    my %v3ext;
    my ($ndx, $pos);
    my $isreq=0;
    my @gr;
	my @fields=('CN','O','OU','L','ST','C');
	my $field;
	foreach $field (@fields){
		if ($crldata=~/^\s*Issuer:.*?\/$field=(.*?)(, [A-Z]{1,2}|\/\w+=|$)/m) { $issuer{$field}=$1; }
	}
	if ($crldata=~/^\s*Signature\s+Algorithm:\s*(.*)$/mi) { $issuer{'sigalgorithm'}=$1;}
 	if ($crldata=~/^\s*Last\s+Update:\s*(.*?)\s*?$/m) { $v3ext{'lastupdate'}=$1; }
 	if ($crldata=~/^\s*Next\s+Update:\s*(.*?)\s*?$/m) { $v3ext{'nextupdate'}=$1; }
 	if ($crldata=~/^\s*X509v3 CRL Number:\s*(.*?)\s*?$/m) { $v3ext{'crlnum'}=$1; }
	if ($issuer{'L'} && ($issuer{'ST'} || $issuer{'C'})) {$issuer{'L'}.=',';}     #Append commas
	if ($issuer{'ST'} && $issuer{'C'}) {$issuer{'ST'}.=',';}                      #Append commas
    push(@gr, '<span style="font-weight:bold;">'.$text{'crl'}.'</span>');
    push(@gr, '');
    push(@gr, $text{'view_cn'});
    push(@gr, $issuer{'CN'});
    if ($issuer{'O'}) {
        push(@gr, $text{'view_o'});
        push(@gr, $issuer{'O'});
    }
    if ($issuer{'OU'}){
        push(@gr, $text{'view_ou'});
        push(@gr, $issuer{'OU'});
    }
    if ($issuer{'L'} || $issuer{'ST'} || $issuer{'C'}) {
        push(@gr, $text{'view_location'});
        push(@gr, $issuer{'L'}.$issuer{'ST'}.$issuer{'C'});
    }
    if ($issuer{'sigalgorithm'}) {
        push(@gr, $text{'view_sig_algorithm'});
        push(@gr, $issuer{'sigalgorithm'});
    }
    if ($v3ext{'lastupdate'}) {
        push(@gr, $text{'view_last_update'});
        push(@gr, $v3ext{'lastupdate'});
    }
    if ($v3ext{'nextupdate'}) {
        push(@gr, $text{'view_next_update'});
        push(@gr, $v3ext{'nextupdate'});
    }
    if ($v3ext{'crlnum'}) {
        push(@gr, $text{'view_crl_number'});
        push(@gr, $v3ext{'crlnum'});
    }
    if ($full) {
        push(@gr, "$text{'view_revoked_certs'}:");
        push(@gr, "");
        $ndx = index($crldata, "Serial Number:");
        while ($ndx gt 0) {
            $crldata = substr($crldata, $ndx);
            $crldata=~/^\s*Serial Number:\s*(.*)$/mi;
            push(@gr, "<span style=\"padding-left:10%;\">$text{'view_serial'}</span>");
            push(@gr, $1);
            $crldata=~/^\s*Revocation Date:\s*(.*)$/mi;
            push(@gr, "<span style=\"padding-left:10%;\">$text{'view_revoke_date'}</span>");
            push(@gr, $1);
            $crldata=~/^\s*X509v3 CRL Reason Code:\s*(.*)$/mi;
            push(@gr, "<span style=\"padding-left:10%;\">$text{'view_revoke_reason'}</span>");
            push(@gr, $1);
            $ndx = index($crldata, "Serial Number:", $ndx + 1);
        }
    }
   
   return &ui_grid_table(\@gr, 2, undef, ['style="padding:0;"', 'style="padding:0 0 0.5% 3%;width:65%;"']);
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
