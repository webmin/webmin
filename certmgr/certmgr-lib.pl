# certmgr-lib.pl

BEGIN { push(@INC, ".."); };
use WebminCore;
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
	print <<EOF;
$text{'gencert_password_notice'}
<hr>
<form action=$form.cgi method=post>
<input type=hidden name=submitted value=generate>
<table border>
<tr $tb> <td align=center><b>$text{$form.'_header'}</b></td> </tr>
<tr $cb> <td><table>
<tr><td>$text{$form.'_'.$certfield}</td><td><input name=$certfield size=40 value="$in{$certfield}"></td></tr>
<tr><td>$text{'keyfile'}</td><td><input name=keyfile size=40 value="$in{'keyfile'}"></td></tr>
EOF
	if ($form eq "gencert"){
		print "<tr><td>$text{'keycertfile'}</td><td><input name=keycertfile size=40 value=\"$in{'keycertfile'}\"></td></tr>";
	}
print <<EOF;
<tr><td>$text{'password'}</td><td><input name=password size=40 type=password value="$in{'password'}"></td></tr>
<tr><td>$text{'confirm_password'}</td><td><input name=confirm_password size=40 type=password value="$in{'confirm_password'}"></td></tr>
<tr><td>$text{'keysize'}</td><td>
<table width=100%><tr>
<td width=33%><input name=keysize type=radio value=512$checked[0]> 512</td>
<td width=33%><input name=keysize type=radio value=1024$checked[1]> 1024</td>
<td width=33%><input name=keysize type=radio value=2048$checked[2]> 2048</td>
</tr></table>
</td></tr>
EOF
	if ($form eq "gencert"){
		print <<EOF;
<tr><td>$text{$form.'_days'}</td><td><input name=days size=40 value="$in{'days'}"></td></tr>
EOF
	}
	print <<EOF;
<tr><td>$text{'cn'}</td><td><input name=cn size=40 value="$in{'cn'}"></td></tr>
<tr><td>$text{'o'}</td><td><input name=o size=40 value="$in{'o'}"></td></tr>
<tr><td>$text{'ou'}</td><td><input name=ou size=40 value="$in{'ou'}"></td></tr>
<tr><td>$text{'l'}</td><td><input name=l size=40 value="$in{'l'}"></td></tr>
<tr><td>$text{'st'}</td><td><input name=st size=40 value="$in{'st'}"></td></tr>
<tr><td>$text{'c'}</td><td><input name=c size=2 maxlength=2 value="$in{'c'}"></td></tr>
<tr><td>$text{'emailAddress'}</td><td><input name=emailAddress size=40 value="$in{'emailAddress'}"></td></tr>
<tr> <td colspan=2 align=right>
<input type=reset value="$text{'reset'}">
<input type=submit value="$text{$form.'_generate'}"></td> </tr>

</table></td></tr></table>
</form>
EOF
}

sub print_sign_form {
	my $form=$_[0];
	my $certfield;
	print <<EOF;
$text{'signcsr_desc'}
<hr>
<form action=$form.cgi method=post>
<input type=hidden name=submitted value=sign>
<table border>
<tr $tb> <td align=center><b>$text{'signcsr_header'}</b></td> </tr>
<tr $cb> <td><table>
<tr><td>$text{'signcsr_csrfile'}</td><td><input name=csrfile size=40 value="$in{'csrfile'}"></td></tr>
<tr><td>$text{'signcsr_signfile'}</td><td><input name=signfile size=40 value="$in{'signfile'}"></td></tr>
<tr><td>$text{'signcsr_keyfile'}</td><td><input name=keyfile size=40 value="$in{'keyfile'}"></td></tr>
<tr><td>$text{'signcsr_keycertfile'}</td><td><input name=keycertfile size=40 value="$in{'keycertfile'}"></td></tr>
<tr><td><a onClick='window.open("/help.cgi/certmgr/signcsr_ca_pass", "help", "toolbar=no,menubar=no,scrollbars=yes,width=400,height=300,resizable=yes"); return false' href="/help.cgi/certmgr/signcsr_ca_pass"><b>$text{'signcsr_ca_passphrase'}</b></a></td><td> <input name=password size=40 type=password value="$in{'password'}"> </td></tr>
<tr><td>$text{'signcsr_days'}</td><td><input name=days size=40 value="$in{'days'}"></td></tr>
<tr> <td colspan=2 align=right>
<input type=reset value="$text{'reset'}">
<input type=submit value="$text{'signcsr_generate'}"></td> </tr>

</table></td></tr></table>
</form>
EOF
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
