# mod_ssl.pl
# Defines editors for mod_ssl directives

sub mod_ssl_directives
{
local($rv);
$rv = [ [ 'SSLEngine', 0, 14, 'virtual', undef, 10 ],
	[ 'SSLProtocol', 0, 14, 'virtual', undef, 10 ],
	[ 'SSLCertificateFile', 0, 14, 'virtual', undef, 9 ],
	[ 'SSLCertificateKeyFile', 0, 14, 'virtual', undef, 8 ],
	[ 'SSLCACertificateFile', 0, 14, 'virtual', undef, 7.7 ],
	[ 'SSLPassPhraseDialog', 1, 14, 'global', 2.0, 7.5 ],
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
if ($in{'SSLEngine'} eq 'on' &&
    $in{'SSLCertificateFile_def'}) {
	# SSL enabled but no cert .. fail
	&error($text{'mod_ssl_ecerton'});
	}
return &parse_choice("SSLEngine");
}

sub get_sslprotos
{
my @sslprotos = ("SSLv2", "SSLv3", "TLSv1" );
if ($httpd_modules{'core'} >= 2.215) {
	push(@sslprotos, "TLSv1.1", "TLSv1.2");
	}
return @sslprotos;
}

sub edit_SSLProtocol
{
local ($rv, $p, %prot);
local @list = $_[0] ? @{$_[0]->{'words'}} : ("all");
foreach $p (@list) {
	if ($p =~ /^\+?all$/i) { map { $prot{lc($_)} = 1 } &get_sslprotos(); }
	elsif ($p =~ /^\-all$/i) { undef(%prot); }
	elsif ($p =~ /^\-(\S+)/) { $prot{lc($1)} = 0; }
	elsif ($p =~ /^\+(\S+)/) { $prot{lc($1)} = 1; }
	}
foreach $p (&get_sslprotos()) {
	$rv .= sprintf "<input type=checkbox name=SSLProtocol value=$p %s> $p ",
		$prot{lc($p)} ? "checked" : "";
	}
return (1, $text{'mod_ssl_proto'}, $rv);
}
sub save_SSLProtocol
{
local @sel = split(/\0/, $in{'SSLProtocol'});
if (scalar(@sel) == scalar(&get_sslprotos())) { return ( [ ] ); }
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

sub edit_SSLCACertificateFile
{
return (2, $text{'mod_ssl_cafile'},
	&opt_input($_[0]->{'value'}, "SSLCACertificateFile", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCACertificateFile", 0));
}
sub save_SSLCACertificateFile
{
return &parse_opt("SSLCACertificateFile", '\S', $text{'mod_ssl_ecafile'});
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
local $table = &ui_columns_start();
local $i = 0;
foreach my $p (@{$_[0]}, { }) {
	local ($mode, $script, $pass, $file);
	if ($p->{'value'} eq 'builtin') {
		$mode = 1;
		}
	elsif ($p->{'value'} =~ /^exec:(.*)$/) {
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
	elsif ($p->{'value'}) {
		$script = $p->{'value'};
		$mode = 1;
		}
	else {
		$mode = 0;
		}
	$table .= &ui_columns_row([
		&ui_radio("SSLPassPhraseDialog_$i", $mode,
			[ [ 0, $text{'mod_ssl_passnone'}."<br>" ],
			  [ 1, $text{'mod_ssl_builtin'}."<br>" ],
			  [ 2, &text('mod_ssl_passph',
			     &ui_textbox("SSLPassPhraseDialog_pass_$i",
					 $pass, 20))."<br>" ],
			  [ 3, &text('mod_ssl_passsc', 
			     &ui_textbox("SSLPassPhraseDialog_script_$i",
					 $script, 40)) ],
			])."\n".
		&ui_hidden("SSLPassPhraseDialog_file_$i", $file)
		]);
	$i++;
	}
$table .= &ui_columns_end();
return (2, $text{'mod_ssl_pass'}, $table);
}
sub save_SSLPassPhraseDialog
{
local @rv;
local $mode;
for(my $i=0; defined($in{"SSLPassPhraseDialog_$i"}); $i++) {
	if ($in{"SSLPassPhraseDialog_$i"} == 0) {
		# Nothing to add
		}
	elsif ($in{"SSLPassPhraseDialog_$i"} == 1) {
		push(@rv, "builtin");
		}
	elsif ($in{"SSLPassPhraseDialog_$i"} == 2) {
		$in{"SSLPassPhraseDialog_pass_$i"} =~ /\S/ ||
			&error($text{'mod_ssl_epassph'});
		local $file = $in{"SSLPassPhraseDialog_file_$i"} ||
			"$config{'httpd_dir'}/passphrase.".time().".sh";
		&open_tempfile(PASS, ">$file");
		&print_tempfile(PASS, "#!/bin/sh\n");
		&print_tempfile(PASS, "echo ",
			$in{"SSLPassPhraseDialog_pass_$i"},"\n");
		&close_tempfile(PASS);
		&set_ownership_permissions(undef, undef, 0755, $file);
		push(@rv, "exec:$file");
		}
	elsif ($in{"SSLPassPhraseDialog_$i"} == 3) {
		if ($in{"SSLPassPhraseDialog_script_$i"} =~ /^[a-z]+:/) {
			push(@rv, $in{"SSLPassPhraseDialog_script_$i"});
			}
		else {
			$in{"SSLPassPhraseDialog_script_$i"} =~ /^\/\S/ ||
				&error($text{'mod_ssl_epasssc'});
			push(@rv, "exec:".$in{"SSLPassPhraseDialog_script_$i"});
			}
		}
	}
return ( \@rv );
}

