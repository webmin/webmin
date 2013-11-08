#!/usr/local/bin/perl
# import.cgi
# Import Signed Certificates and Keys

require './certmgr-lib.pl';
$access{'import'} || &error($text{'ecannot'});
if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	&ReadParseMime();
	}
&header($text{'import_title'}, "");

if ($in{'submitted'} eq "import") {
	if ($in{'import'} eq $text{'import_upload_cert'}){
		$type="cert";
	} elsif ($in{'import'} eq $text{'import_upload_key'}){
		$type="key";
	}
	$filename="$in{$type.'_directory'}/$in{$type.'_file_filename'}";
	$filename=~s#//#/#g;
	if (!$in{$type.'_directory'}) { 
		$error.="<li> $text{'import_e_nodir'}<br>\n";
	}
	if (!$in{$type.'_file_filename'}) {
		$error.="<li> $text{'import_e_nofilename'}<br>\n";
	} 
	if (!$in{$type.'_file_upload'}) {
		$error.="<li> $text{'import_e_nofile'}<br>\n";
	}
	if (!$error) {
		if ((-e $filename)&&(!$in{'overwrite'})) {
			&overwriteprompt($type);
		}
		&receive($type);
		exit;
	}
}

if ($error) {
	print "<hr> <b>$text{'import_error'}</b>\n<ul>\n";
	print "$error</ul>\n$text{'import_pleasefix'}\n";
}
if (!$in{'cert_directory'}) { $in{'cert_directory'}=$config{'ssl_cert_dir'}; }
if (!$in{'key_directory'}) { $in{'key_directory'}=$config{'ssl_key_dir'}; }
if (!$in{'cert_file_filename'}) { $in{'cert_file_filename'}=$config{'cert_filename'}; }
if (!$in{'key_file_filename'}) { $in{'key_file_filename'}=$config{'key_filename'}; }
	
print <<EOF;
<hr>
<form action="import.cgi" enctype=multipart/form-data method=post>
<input type=hidden name="submitted" value="import">
<table border>
<tr $tb> <td><center><b>$text{'import_header'}</b></center></td> </tr>
<tr $cb> <td>
 <table width=100%>
 <tr> <td width=35%><b>$text{'import_cert_file'}</b></td>
 <td width=65%><input name="cert_file_upload" type="file" size="48" value="$in{'cert_file_upload_filename'}"></td></tr>
 <tr> <td><b>$text{'import_cert_destination'}</b></td>
 <td><select name=cert_directory>
EOF
print "  <option value='' ";
if (!$in{'cert_directory'}) {print "selected";}
print ">$text{'import_choose'}</option>";
foreach $f ( &getdirs($config{'ssl_dir'})) {
        if ($config{'ssl_dir'}."/".$f eq $in{'cert_directory'}) {print "  <option selected>$config{'ssl_dir'}/$f</option>\n";}
        else {print "  <option>$config{'ssl_dir'}/$f</option>\n";}
        }
print <<EOF;
 </select></td> </tr>
 <tr><td><b>$text{'import_cert_filename'}</b></td><td><input name="cert_file_filename" size="48" value="$in{'cert_file_filename'}"></td></tr>
 <tr> <td colspan=2 align=right>
 <input type=reset value="$text{'import_reset'}">
 <input type=submit name=import value="$text{'import_upload_cert'}"></td> </tr>
 </table>
</td></tr>
<tr $cb><td>
 <table width=100%>
 <tr> <td width=35%><b>$text{'import_key_file'}</b></td>
 <td width=65%><input name="key_file_upload" type="file" size="48" value="$in{'key_file_upload_filename'}"></td></tr>
 <tr> <td><b>$text{'import_key_destination'}</b></td>
 <td><select name=key_directory>
EOF
print "  <option value='' ";
if (!$in{'key_directory'}) {print "selected";}
print ">$text{'import_choose'}</option>";
foreach $f ( &getdirs($config{'ssl_dir'})) {
        if ($config{'ssl_dir'}."/".$f eq $in{'key_directory'}) {print "  <option selected>$config{'ssl_dir'}/$f</option>\n";}
        else {print "  <option>$config{'ssl_dir'}/$f</option>\n";}
        }
print <<EOF;
 </select></td> </tr>
 <tr> <td><b>$text{'import_key_filename'}</b></td><td><input name="key_file_filename" size="48" value="$in{'key_file_filename'}"></td></tr>
 <tr> <td colspan=2 align=right>
 <input type=reset value="$text{'import_reset'}">
 <input type=submit name="import" value="$text{'import_upload_key'}"></td> </tr>
 </table>
</td></tr></table></form>
<hr>
EOF
&footer("", $text{'import_return'});

sub getdirs {
	my(@dirs,@subdirs,$thisdir);
	$thisdir=$_[0];
	opendir(DIR, $thisdir);
	@dirs= sort grep { !/^[.]{1,2}$/ && -d "$thisdir/$_" } readdir(DIR);
	closedir(DIR);
	foreach $dir (@dirs) {
		push(@subdirs, $dir);
		push(@subdirs, grep { $_=$dir.'/'.$_ } &getdirs($thisdir."/".$dir));
	}
	return(@subdirs);
}

sub receive {
	my $type=$_[0];
	open(FILE,">$filename");
	print FILE $in{$type.'_file_upload'};
	close(FILE);
	if ($type eq "cert") { chmod(0644,$filename); }
	elsif ($type eq "key") { chmod(0400,$filename); }
	print &ui_hr();
	print "<h4>File $filename uploaded successfully</h4>\n";
	print &ui_hr();
	&footer("", $text{'import_return'});
}

sub overwriteprompt{
	my $type=$_[0];
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
	
	print "<table>\n<tr valign=top>";
	if ($type eq "cert") {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $filename -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="\"view.cgi?certfile=".&my_urlize($filename).'"';
		print "<td><table border><tr $tb><td align=center><b><a href=$url>$filename</a></b></td> </tr>\n<tr $cb> <td>\n";
		if (!$buffer1) { print $text{'e_file'};}
		else { &print_cert_info(0,$buffer1); }
		print "</td></tr></table></td>\n";
	}
	if ($type eq "key") {
		open(OPENSSL,"$config{'openssl_cmd'} rsa -in $filename -text -noout|");
		while(<OPENSSL>){ $buffer.=$_; }
		close(OPENSSL);
		$url="\"view.cgi?keyfile=".&my_urlize($filename).'"';
		print "<td><table border><tr $tb> <td align=center><b><a href=$url>$filename</a></b></td> </tr>\n<tr $cb> <td>\n";
		if (!$buffer) { print $text{'e_file'};}
		else { &print_key_info(0,$buffer); }
		print "</td></tr></table></td>\n";
	}
	print "</tr></table>\n";
	print "$text{'gencert_moreinfo'}";
	print "<hr>\n$text{'gencert_overwrite'}\n<p>\n";
	
	print "<form action=import.cgi enctype=multipart/form-data method=post>\n";
	foreach $key (keys %in) {
		print "<input name=\"$key\" type=hidden value=\"$in{$key}\">\n";
	}
	print "<input name=overwrite value=\"yes\" type=hidden>\n";
	print "<input type=submit value=\"$text{'continue'}\"></form>\n";
}
