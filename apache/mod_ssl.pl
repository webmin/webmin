# mod_ssl.pl
# Defines editors for mod_ssl directives

sub mod_ssl_directives
{
local($rv);
$rv = [ [ 'SSLEngine', 0, 14, 'virtual', undef, 10 ],
	[ 'SSLProtocol', 0, 14, 'virtual', undef, 10 ],
	[ 'SSLCertificateFile', 0, 14, 'virtual', undef, 9 ],
	[ 'SSLCertificateKeyFile', 0, 14, 'virtual', undef, 8 ],
	[ 'SSLPassPhraseDialog', 0, 14, 'virtual', 2.0, 7.5 ],
	[ 'SSLVerifyClient', 0, 14, 'virtual directory htaccess', undef, 7 ],
	[ 'SSLVerifyDepth', 0, 14, 'virtual directory htaccess', undef, 6 ],
	[ 'SSLLog', 0, 14, 'virtual', undef, 5 ],
	[ 'SSLRequireSSL', 0, 14, 'directory htaccess', undef, 4 ],
      ];
return &make_directives($rv, $_[0], "mod_ssl");
}

sub edit_SSLEngine
{
return (1, $text{'mod_ssl_enable'},
	&choice_input($_[0]->{'value'}, "SSLEngine", "",
	      "$text{'yes'},on", "$text{'no'},off", "$text{'default'},"));
}
sub save_SSLEngine
{
return &parse_choice("SSLEngine");
}

@sslprotos = ("SSLv2", "SSLv3", "TLSv1");
sub edit_SSLProtocol
{
local ($rv, $p, %prot);
local @list = $_[0] ? @{$_[0]->{'words'}} : ("all");
foreach $p (@list) {
	if ($p =~ /^\+?all$/i) { map { $prot{lc($_)} = 1 } @sslprotos; }
	elsif ($p =~ /^\-all$/i) { undef(%prot); }
	elsif ($p =~ /^\-(\S+)/) { $prot{lc($1)} = 0; }
	elsif ($p =~ /^\+(\S+)/) { $prot{lc($1)} = 1; }
	}
foreach $p (@sslprotos) {
	$rv .= sprintf "<input type=checkbox name=SSLProtocol value=$p %s> $p ",
		$prot{lc($p)} ? "checked" : "";
	}
return (1, $text{'mod_ssl_proto'}, $rv);
}
sub save_SSLProtocol
{
local @sel = split(/\0/, $in{'SSLProtocol'});
if (scalar(@sel) == scalar(@sslprotos)) { return ( [ ] ); }
return ( [ join(" ", (map { "+$_" } @sel)) ] );
}

sub edit_SSLCertificateFile
{
return (2, $text{'mod_ssl_cfile'},
	&opt_input($_[0]->{'value'}, "SSLCertificateFile", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCertificateFile", 0));
}
sub save_SSLCertificateFile
{
return &parse_opt("SSLCertificateFile", '\S', $text{'mod_ssl_ecfile'});
}

sub edit_SSLCertificateKeyFile
{
return (2, $text{'mod_ssl_kfile'},
	&opt_input($_[0]->{'value'}, "SSLCertificateKeyFile", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCertificateKeyFile", 0));
}
sub save_SSLCertificateKeyFile
{
return &parse_opt("SSLCertificateKeyFile", '\S', $text{'mod_ssl_ekfile'});
}

sub edit_SSLVerifyClient
{
return (1, $text{'mod_ssl_clcert'},
	&select_input($_[0]->{'value'}, "SSLVerifyClient", "",
		      "$text{'default'},", "$text{'mod_ssl_nreq'},none",
		      "$text{'mod_ssl_opt'},optional",
		      "$text{'mod_ssl_req'},require",
		      "$text{'mod_ssl_optca'},optional_no_ca"));
}
sub save_SSLVerifyClient
{
return &parse_select("SSLVerifyClient");
}

sub edit_SSLVerifyDepth
{
return (1, $text{'mod_ssl_cdepth'},
	&opt_input($_[0]->{'value'}, "SSLVerifyDepth", $text{'mod_ssl_default'}, 6));
}
sub save_SSLVerifyDepth
{
return &parse_opt("SSLVerifyDepth", '^\d+$', $text{'mod_ssl_ecdepth'});
}

sub edit_SSLLog
{
return (1, $text{'mod_ssl_log'},
	&opt_input($_[0]->{'value'}, "SSLLog", $text{'mod_ssl_default'}, 20));
}
sub save_SSLLog
{
return &parse_opt("SSLLog", '\S', $text{'mod_ssl_elog'});
}

sub edit_SSLRequireSSL
{
return (1, $text{'mod_ssl_onlyssl'},
	&choice_input($_[0] ? 1 : 0, "SSLRequireSSL", 0, "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLRequireSSL
{
return $in{'SSLRequireSSL'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLPassPhraseDialog
{
local ($mode, $script, $pass, $file);
if ($_[0]->{'value'} eq 'builtin') {
	$mode = 1;
	}
elsif ($_[0]->{'value'} =~ /^exec:(.*)$/) {
	$file = $1;
	local $data = &read_file_contents($1);
	if ($data =~ /^#!\/bin\/sh\necho\s(.*)\n$/) {
		$pass = $1;
		$mode = 2;
		}
	else {
		$script = $file;
		$file = undef;
		$mode = 3;
		}
	}
elsif ($_[0]->{'value'}) {
	$script = $_[0]->{'value'};
	$mode = 1;
	}
else {
	$mode = 0;
	}
return (2, $text{'mod_ssl_pass'},
	&ui_radio("SSLPassPhraseDialog", $mode,
		[ [ 0, $text{'default'} ],
		  [ 1, $text{'mod_ssl_builtin'}."<br>" ],
		  [ 2, &text('mod_ssl_passph',
		     &ui_textbox("SSLPassPhraseDialog_pass", $pass, 20))."<br>" ],
		  [ 3, &text('mod_ssl_passsc', 
		     &ui_textbox("SSLPassPhraseDialog_script", $script, 40)) ],
		])."\n".
	&ui_hidden("SSLPassPhraseDialog_file", $file));
}
sub save_SSLPassPhraseDialog
{
if ($in{'SSLPassPhraseDialog'} == 0) {
	return ( [ ] );
	}
elsif ($in{'SSLPassPhraseDialog'} == 1) {
	return ( [ "builtin" ] );
	}
elsif ($in{'SSLPassPhraseDialog'} == 2) {
	$in{'SSLPassPhraseDialog_pass'} =~ /\S/ ||
		&error($text{'mod_ssl_epassph'});
	local $file = $in{'SSLPassPhraseDialog_file'} ||
		"$config{'httpd_dir'}/passphrase.".time().".sh";
	&open_tempfile(PASS, ">$file");
	&print_tempfile(PASS, "#!/bin/sh\n");
	&print_tempfile(PASS, "echo ",$in{'SSLPassPhraseDialog_pass'},"\n");
	&close_tempfile(PASS);
	&set_ownership_permissions(undef, undef, 0755, $file);
	return ( [ "exec:$file" ] );
	}
elsif ($in{'SSLPassPhraseDialog'} == 3) {
	if ($in{'SSLPassPhraseDialog_script'} =~ /^[a-z]+:/) {
		return ( [ $in{'SSLPassPhraseDialog_script'} ] );
		}
	else {
		$in{'SSLPassPhraseDialog_script'} =~ /^\/\S/ ||
			&error($text{'mod_ssl_epasssc'});
		return ( [ "exec:".$in{'SSLPassPhraseDialog_script'} ] );
		}
	}
}

