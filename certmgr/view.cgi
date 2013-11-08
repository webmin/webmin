#!/usr/local/bin/perl
# view.cgi
# Views certificates and keys in detail

require './certmgr-lib.pl';
$access{'view'} || &error($text{'ecannot'});
&ReadParse();

if (!$in{'wildcard'}){$in{'wildcard'}=$config{'default_wildcard'}}
$wildcard_pattern=$in{'wildcard'};
$wildcard_pattern=~s/\./\\./g;
$wildcard_pattern=~s/\*/[^\/]*?/g;
$wildcard_pattern=~s/\?/./g;


if ($in{'dl'} ne "yes" && $in{'pkcs12'} ne "yes") {
	&header($text{'view_title'}, "");
	print &ui_hr();
}
if ($in{'delete'} eq "yes"){
	if ($in{'keyfile'}) { $file=$in{'keyfile'} }
	elsif ($in{'certfile'}) { $file=$in{'certfile'} }
	elsif ($in{'csrfile'}) { $file=$in{'csrfile'} }
	elsif ($in{'keycertfile'}) { $file=$in{'keycertfile'} }
	if (!($file)&&((-f $file)||(-s $file))){ print "<b>$file</b>: $text{'view_e_nofile'}\n<p>\n"; }
	if (unlink($file)) { print "<b>$file</b>: $text{'view_deleted'}\n<p>\n"; }
	else { print "<b>$file</b>: $text{'view_e_not_deleted'}\n<p>\n"; }
	&footer("", $text{'index_return'});
	exit;
}

if (($in{'filename'}) && ($in{'view'} eq $text{'view_view'})) {
	$in{'filename'}=$config{'ssl_dir'}."/".$in{'filename'};
	if (!open(FILE,$in{'filename'})) {
		print "$text{'e_file'}\n<p>\n";
		&footer("", $text{'index_return'});
		exit;
	}
	while(<FILE>){ $buffer.=$_;}
	if ($buffer=~/^\s*-+BEGIN\s*RSA\s*PRIVATE\s*KEY-*\s*$/mi) { $key=1; }
	if ($buffer=~/^\s*-+BEGIN\s*CERTIFICATE-*\s*$/mi) { $cert=1; }
	if ($buffer=~/^\s*-+BEGIN\s*CERTIFICATE\s*REQUEST-*\s*$/mi) { $csr=1; }
	if (($key)&&($cert)) {$in{'keycertfile'}=$in{'filename'};}
	elsif ($key) {$in{'keyfile'}=$in{'filename'};}
	elsif ($cert) {$in{'certfile'}=$in{'filename'};}
	elsif ($csr) {$in{'csrfile'}=$in{'filename'};}
	else {
		print "$text{'e_file'}<br>\n$text{'e_notcert'}\n<p>\n";
		&footer("", $text{'index_return'});
		exit;
	}
	undef($buffer);
	undef($key);
	undef($cert);
		
}

if ($in{'keyfile'}) {
	if ($in{'dl'} eq 'yes') {
		# Just output in PEM format
		&output_cert($in{'keyfile'});
	} elsif ($in{'pkcs12'} eq 'yes') {
		# Just output in PKCS8 format
		&output_pkcs12($in{'keyfile'});
	}

	open(OPENSSL,"$config{'openssl_cmd'} rsa -in $in{'keyfile'} -text -noout|");
	while(<OPENSSL>){ $buffer.=$_; }
	close(OPENSSL);
	print "<table border><tr $tb> <td align=center><b>$in{'keyfile'}</b></td> </tr>\n<tr $cb> <td>\n";
	if (!$buffer) { print $text{'e_file'};}
	else {&print_key_info(1,$buffer);}
	print "</td></tr></table>\n";
	&download_form("keyfile", $in{'keyfile'}, $text{'key'});
	print &ui_hr();
	&footer("", $text{'index_return'});
	exit;
}
if ($in{'certfile'}||$in{'csrfile'}) {
	if ($in{'csrfile'}){
		$in{'certfile'}=$in{'csrfile'};
		$text{'certificate'}=$text{'csr'};
	}
	if ($in{'dl'} eq 'yes') {
		# Just output in PEM format
		&output_cert($in{'certfile'});
	} elsif ($in{'pkcs12'} eq 'yes') {
		# Just output in PKCS8 format
		&output_pkcs12($in{'certfile'});
	}

	if ($in{'csrfile'}) {
		open(OPENSSL,"$config{'openssl_cmd'} req -in $in{'certfile'} -text -noout|");
	} else {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'certfile'} -text -fingerprint -noout|");
	}
	while(<OPENSSL>){ $buffer.=$_; }
	close(OPENSSL);
	print "<table border><tr $tb> <td align=center><b>$in{'certfile'}</b></td> </tr>\n<tr $cb> <td>\n";
	if (!$buffer) { print $text{'e_file'};}
	else {&print_cert_info(1,$buffer);}
	print "</td></tr></table>\n";
	&download_form("certfile", $in{'certfile'}, $text{'certificate'});
	print &ui_hr();
	&footer("", $text{'index_return'});
	exit;
}
if ($in{'keycertfile'}) {
	if ($in{'dl'} eq 'yes') {
		# Just output in PEM format
		&output_cert($in{'keycertfile'});
	} elsif ($in{'pkcs12'} eq 'yes') {
		# Just output in PKCS8 format
		&output_pkcs12($in{'keycertfile'});
	}

	open(OPENSSL,"$config{'openssl_cmd'} x509 -in $in{'keycertfile'} -text -fingerprint -noout|");
	while(<OPENSSL>){ $buffer.=$_; }
	close(OPENSSL);
	print "<table border><tr $tb> <td align=center colspan=2><b>$in{'keycertfile'}</b></td> </tr>\n";
			print "<tr $cb><td align=center><b>$text{'certificate'}</b></td><td align=center><b>$text{'key'}</b></td></tr>\n<tr $cb valign=top> <td>\n";
	if (!$buffer) { print $text{'e_file'};}
	else {&print_cert_info(1,$buffer);}
	print "</td><td>\n";
	undef($buffer);
	open(OPENSSL,"$config{'openssl_cmd'} rsa -in $in{'keycertfile'} -text -noout|");
	while(<OPENSSL>){ $buffer.=$_; }
	close(OPENSSL);
	if (!$buffer) { print $text{'e_file'};}
	else {&print_key_info(1,$buffer);}
	print "</td></tr></table>\n";
	&download_form("keycertfile", $in{'keycertfile'},
		       "$text{'certificate'} / $text{'key'}");
	print &ui_hr();
	&footer("", $text{'index_return'});
	exit;
}


print "<form action=view.cgi method=post>\n";
print "<table border>\n<tr $tb> <td><center><b>$text{'view_select'}</b></center></td> </tr>\n";
print "<tr $cb><td><table border=0><td>$text{'view_wildcard'}:</td><td><input name=wildcard value=\"$in{'wildcard'}\"></td>";
print "<td><input type=submit name=update value=\"$text{'view_update'}\"></td></tr>\n";
print "<tr><td colspan=2><select name=filename>\n";
print "<option value='' selected>$text{'view_choose'}</option>\n";
foreach $f ( grep { /^(.*\/)*$wildcard_pattern$/ && -f "$config{'ssl_dir'}/$_" } &getfiles($config{'ssl_dir'})) { 
	print "<option value=\"$f\">$config{'ssl_dir'}/$f</option>\n"; 
}
print "</select>\n";
print "</td><td><input type=submit name=view value=\"$text{'view_view'}\"></td></tr></table></td></tr></table>\n";
print "</form>\n";
print &ui_hr();
&footer("", $text{'index_return'});

sub output_cert
{
print "Content-type: text/plain\n\n";
open(OPENSSL, $_[0]);
while(<OPENSSL>){ print; }
close(OPENSSL);
exit;
}

sub output_pkcs12
{
print "Content-type: application/pkcs12\n\n";
local $qp = quotemeta($in{'pass'});
open(OPENSSL, "$config{'openssl_cmd'} pkcs12 -in $_[0] -export -passout pass:$qp |");
while(<OPENSSL>){ print; }
close(OPENSSL);
exit;
}

sub pkcs12_filename
{
local $fn = &my_urlize($_[0]);
$fn =~ s/\.pem$/\.p12/i;
return $fn;
}

# download_form(mode, file, suffix)
sub download_form
{
local ($mode, $keyfile, $suffix) = @_;
$suffix = "";
$keyfile =~ /\/([^\/]*)$/;
local $filename = &my_urlize($1);
local $p12filename = &pkcs12_filename($1);

print "<table border=0><tr><td>\n";
print "<form action=view.cgi/$filename method=post>\n";
print "<input type=hidden name=dl value=yes>\n";
print "<input type=hidden name=$mode value=\"$keyfile\">\n";
print "<input type=submit value=\"$text{'view_download'} $suffix\"></form>\n";
print "</td><td>\n";

print "<form action=view.cgi/$p12filename method=post>\n";
print "<input type=hidden name=pkcs12 value=yes>\n";
print "<input type=hidden name=$mode value=\"$keyfile\">\n";
print "<input type=submit value=\"$text{'view_download'} $suffix $text{'view_pkcs12'}\">\n";
print "<input type=password name=pass size=20>\n";
print "</form>\n";
print "</td><td>\n";

print "<form action=view.cgi method=post>\n";
print "<input type=hidden name=delete value=yes>\n";
print "<input type=hidden name=$mode value=\"$keyfile\">\n";
print "<input type=submit value=\"$text{'view_delete'} $suffix\"></form>\n";
print "</td></tr></table>\n";
}

