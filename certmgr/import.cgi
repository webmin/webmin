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

print &ui_hr();
print &ui_form_start("import.cgi", "form-data");
print &ui_hidden("submitted","import");
print &ui_table_start($text{'import_header'}, undef, 2);
print &ui_table_row($text{'import_cert_file'}, &ui_upload("cert_file_upload", 48, undef, "value=\"$in{'cert_file_upload_filename'}\""), undef, $valign_middle );

my @cert_directory;
push(@cert_directory, [ "", $text{'import_choose'}, ( !$in{'cert_directory'} ? "selected" : "" ) ]);
foreach $f (&getdirs($config{'ssl_dir'})) {
    $sel = ( $config{'ssl_dir'}."/".$f eq $in{'cert_directory'} ? "selected" : "" );
    $dir = $config{'ssl_dir'}."/".$f;
    push(@cert_directory, [ $dir, $dir, $sel ]);
}
print &ui_table_row($text{'import_cert_destination'},
        &ui_select("cert_directory", undef, \@cert_directory)
        , undef, $valign_middle);

print &ui_table_row($text{'import_cert_filename'}, &ui_textbox("cert_file_filename", $in{'cert_file_filename'}, 48), undef, $valign_middle);
print &ui_table_row("&nbsp;",&ui_reset($text{'import_reset'})." ".&ui_submit($text{'import_upload_cert'},"import"), undef, $valign_middle);

print &ui_table_hr();
print &ui_table_row($text{'import_key_file'}, &ui_upload("key_file_upload", 48, undef, "value=\"$in{'key_file_upload_filename'}\""), undef, $valign_middle);

my @key_directory;
push(@key_directory, [ "", $text{'import_choose'}, ( !$in{'key_directory'} ? "selected" : "" ) ]);
foreach $f (&getdirs($config{'ssl_dir'})) {
    $sel = ( $config{'ssl_dir'}."/".$f eq $in{'key_directory'} ? "selected" : "" );
    $dir = $config{'ssl_dir'}."/".$f;
    push(@key_directory, [ $dir, $dir, $sel ]);
}
print &ui_table_row($text{'import_key_destination'},
        &ui_select("key_directory", undef, \@key_directory)
        ,undef, $valign_middle);

print &ui_table_row($text{'import_key_filename'}, &ui_textbox("key_file_filename", $in{'key_file_filename'}, 48), undef, $valign_middle);
print &ui_table_row("&nbsp;",&ui_reset($text{'import_reset'})." ".&ui_submit($text{'import_upload_key'},"import"), undef, $valign_middle);

print &ui_table_end();
print &ui_form_end();
print &ui_hr();

&footer("", $text{'index_return'});

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
	&footer("", $text{'index_return'});
}

sub overwriteprompt{
	my $type=$_[0];
	my($buffer1,$buffer2,$buffer,$key,$temp_pem,$url);
	my $rv = "";
    my $link = "";
	if ($type eq "cert") {
		open(OPENSSL,"$config{'openssl_cmd'} x509 -in $filename -text -fingerprint -noout|");
		while(<OPENSSL>){ $buffer1.=$_; }
		close(OPENSSL);
		$url="view.cgi?certfile=".&my_urlize($filename);
        $link = &ui_link($url,$filename);
        $rv = &ui_table_start($link, undef, 2);
        $rv .= &ui_table_row(undef, (!$buffer1 ? $text{'e_file'} : &show_cert_info(0,$buffer1) ) );
	}
	if ($type eq "key") {
		open(OPENSSL,"$config{'openssl_cmd'} rsa -in $filename -text -noout|");
		while(<OPENSSL>){ $buffer.=$_; }
		close(OPENSSL);
		$url="view.cgi?keyfile=".&my_urlize($filename);
        $link = &ui_link($url,$filename);
        $rv = &ui_table_start($link, undef, 2);
        $rv .= &ui_table_row(undef, (!$buffer ? $text{'e_file'} : &show_key_info(0,$buffer) ) );
	}

    print "<br>";
    print $rv;
    print &ui_table_hr();
    print &ui_table_row(undef,$text{'gencert_moreinfo'});
    print &ui_table_row(undef,&ui_hr().$text{'gencert_overwrite'});
    $rv = &ui_form_start("import.cgi", "form-data");
	foreach $key (keys %in) {
        $rv .= &ui_hidden($key,$in{$key});
	}
    $rv .= &ui_hidden("overwrite","yes");
    $rv .= &ui_submit($text{'continue'});
    $rv .= &ui_form_end();
    print &ui_table_row(undef,$rv);
    print &ui_table_end();
}
