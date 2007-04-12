# nodo50 v0.1 - Change 000003 - New Script. Define Editors for mod_apachessl directives (Apache-ssl not use mod_ssl)
# nodo50 v0.1 - Change 000003 - Nuevo Script. Define edición de directivas de mod_apachessl (Apache-ssl no usa mod_ssl)
# mod_apachessl.pl (http://www.apache-ssl.org/)
# Defines editors for mod_apachessl directives

sub mod_apachessl_directives
{
local($rv);
$rv = [ [ 'SSLCacheServerPath', 0, 14, 'global', undef, 59 ],
	[ 'SSLCacheServerPort', 0, 14, 'global', 1.3, 58 ],
	[ 'SSLCacheServerRunDir', 0, 14, 'global', undef, 57 ],
	[ 'SSLRandomFile', 0, 14, 'global', 1.3, 56 ],
	[ 'SSLRandomFilePerConnection', 0, 14, 'global', 1.3, 55 ],
	[ 'SSLEnable SSLDisable', 0, 14, 'virtual', undef, 49 ],
	[ 'SSLNoV2', 0, 14, 'virtual', 1.3, 48 ],
	[ 'SSLRequireSSL SSLDenySSL', 0, 14, 'virtual directory htaccess', 1.3, 47 ],
	[ 'SSLCertificateFile', 0, 14, 'virtual', undef, 39 ],
	[ 'SSLCertificateKeyFile', 0, 14, 'virtual', undef, 38 ],
	[ 'SSLNoCAList', 0, 14, 'virtual', 1.3, 37 ],
	[ 'SSLCACertificatePath', 0, 14, 'virtual', undef, 36 ],
	[ 'SSLCACertificateFile', 0, 14, 'virtual', undef, 35 ],
	[ 'SSLVerifyClient', 0, 14, 'virtual', undef, 29 ],
	[ 'SSLVerifyDepth', 0, 14, 'virtual', undef, 28 ],
	[ 'SSLExportClientCertificates', 0, 14, 'virtual directory htaccess', undef, 27 ],
	[ 'SSLSessionCacheTimeout', 0, 14, 'virtual', undef, 26 ],
	[ 'SSLCheckClientDN', 0, 14, 'virtual', 1.3, 25 ],
	[ 'SSLFakeBasicAuth', 0, 14, 'virtual', undef, 24 ],
	[ 'SSLUseCRL', 0, 14, 'virtual', undef, 23 ],
	[ 'SSLCRLCheckAll', 0, 14, 'virtual', 1.3, 22 ],
	[ 'SSLOnNoCRLSetEnv', 0, 14, 'virtual', 1.3, 21 ],
	[ 'SSLOnCRLExpirySetEnv', 0, 14, 'virtual', 1.3, 20 ],
	[ 'SSLOnRevocationSetEnv', 0, 14, 'virtual', 1.3, 19 ],
	[ 'SSLRequiredCiphers', 0, 14, 'virtual', undef, 3 ],
	[ 'SSLRequireCipher', 0, 14, 'virtual directory htaccess', undef, 2 ],
	[ 'SSLBanCipher', 0, 14, 'virtual directory htaccess', undef, 1 ]
];
return &make_directives($rv, $_[0], "mod_apachessl");
}

sub edit_SSLCacheServerPath
{
return (2, $text{'mod_apachessl_cachepaht'},
	&opt_input($_[0]->{'value'}, "SSLCacheServerPath", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCacheServerPath", 0));SSLRandomFile
}
sub save_SSLCacheServerPath
{
return &parse_opt("SSLCacheServerPath", '\S', $text{'mod_apachessl_ecachepath'});
}

sub edit_SSLCacheServerPort
{
return (2, $text{'mod_apachessl_cacheport'},
	&opt_input($_[0]->{'value'}, "SSLCacheServerPort", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCacheServerPort", 0));
}
sub save_SSLCacheServerPort
{
return $in{SSLCacheServerPort} =~ /^\d+$/ ? &parse_opt("SSLCacheServerPort", '^\d+$', $text{'mod_apachessl_ecacheport'}) :
	&parse_opt("SSLCacheServerPort", '\S', $text{'mod_apachessl_ecacheport'});
}

sub edit_SSLCacheServerRunDir
{
return (2, $text{'mod_apachessl_cacherundir'},
	&opt_input($_[0]->{'value'}, "SSLCacheServerRunDir", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCacheServerRunDir", 0));
}
sub save_SSLCacheServerRunDir
{
return &parse_opt("SSLCacheServerRunDir", '\S', $text{'mod_apachessl_ecacherundir'});
}

sub edit_SSLRandomFile
{
local @sel = split(/\ /, $_[0]->{'value'});
return (2, $text{'mod_apachessl_ramdomfile'},
	&choice_input($sel[0], "SSLRandomFile", "",
		      "$text{'mod_ssl_default'},", "$text{'mod_apachessl_ramdomfilef'},file", "$text{'mod_apachessl_ramdomfilee'},egd").
	'<input name=SSLRandomFileF size=35 value='.$sel[1].'>'.
	&file_chooser_button("SSLRandomFileF", 0).
	'<input name=SSLRandomFileB size=10 value='.$sel[2].'>&nbsp;bytes');
}
sub save_SSLRandomFile
{
if (!$in{SSLRandomFile}) {
	return ( [ ] );
	}
if ($in{SSLRandomFileF} !~ /\S/) {
	&error($text{'mod_apachessl_eramdomfilef'});
	}
if ($in{SSLRandomFileB} !~ /^\d+$/) {
	&error($text{'mod_apachessl_eramdomfileb'});
	}
return ( [ $in{SSLRandomFile}.' '.$in{SSLRandomFileF}.' '.$in{SSLRandomFileB} ] );
}

sub edit_SSLRandomFilePerConnection
{
local @sel = split(/\ /, $_[0]->{'value'});
return (2, $text{'mod_apachessl_ramdomfilepc'},
	&choice_input($sel[0], "SSLRandomFilePerConnection", "",
		      "$text{'mod_ssl_default'},", "$text{'mod_apachessl_ramdomfilef'},file", "$text{'mod_apachessl_ramdomfilee'},egd").
	'<input name=SSLRandomFilePerConnectionF size=35 value='.$sel[1].'>'.
	&file_chooser_button("SSLRandomFileF", 0).
	'<input name=SSLRandomFilePerConnectionB size=10 value='.$sel[2].'>&nbsp;bytes');
}
sub save_SSLRandomFilePerConnection
{
if (!$in{SSLRandomFilePerConnection}) {
	return ( [ ] );
	}
if ($in{SSLRandomFilePerConnectionF} !~ /\S/) {
	&error($text{'mod_apachessl_eramdomfilef'});
	}
if ($in{SSLRandomFilePerConnectionB} !~ /^\d+$/) {
	&error($text{'mod_apachessl_eramdomfileb'});
	}
return ( [ $in{SSLRandomFilePerConnection}.' '.$in{SSLRandomFilePerConnectionF}.' '.$in{SSLRandomFilePerConnectionB} ] );
}

sub edit_SSLEnable_SSLDisable
{
return (1, $text{'mod_ssl_enable'},
	&choice_input($_[0] ? "1" : "0", "SSLEnable", "",
		      "$text{'yes'},1", "$text{'no'},0", "$text{'default'},"));
}
sub save_SSLEnable_SSLDisable
{
return $in{'SSLEnable'} ? ( [ "" ], [ ] ) : ( [ ], [ "" ] );
}

sub edit_SSLNoV2
{
return (1, $text{'mod_apachessl_nov2'},
	&choice_input($_[0] ? 1 : 0, "SSLNoV2", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLNoV2
{
return $in{'SSLNoV2'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLRequireSSL_SSLDenySSL
{
return (2, $text{'mod_apachessl_forcessl'},
	&choice_input($_[0] ? "Require" : $_[1] ? "Deny" : "",
	"SSLRequireSSL", "", "$text{'mod_ssl_onlyssl'},Require", "$text{'mod_apachessl_notssl'},Deny", "$text{'default'},"));
}
sub save_SSLRequireSSL_SSLDenySSL
{
return $in{'SSLRequireSSL'} eq "Require" ? ( [ "" ], [ ] ) : $in{'SSLRequireSSL'} eq "Deny" ? ( [ ], [ "" ]) : ( [ ], [ ] );
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

sub edit_SSLNoCAList
{
return (1, $text{'mod_apachessl_nocalist'},
	&choice_input($_[0] ? 1 : 0, "SSLNoCAList", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLNoCAList
{
return $in{'SSLNoCAList'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLCACertificatePath
{
return (2, $text{'mod_apachessl_capath'},
	&opt_input($_[0]->{'value'}, "SSLCACertificatePath", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCACertificatePath", 0));
}
sub save_SSLCACertificatePath
{
return &parse_opt("SSLCACertificatePath", '\S', $text{'mod_ssl_ecfile'});
}

sub edit_SSLCACertificateFile
{
return (2, $text{'mod_apachessl_cafile'},
	&opt_input($_[0]->{'value'}, "SSLCACertificateFile", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCACertificateFile", 0));
}
sub save_SSLCACertificateFile
{
return &parse_opt("SSLCACertificateFile", '\S', $text{'mod_ssl_ecfile'});
}

sub edit_SSLVerifyClient
{
return (1, $text{'mod_ssl_clcert'},
	&select_input($_[0]->{'value'}, "SSLVerifyClient", "",
		      "$text{'default'},", "$text{'mod_ssl_nreq'},",
		      "$text{'mod_ssl_opt'},1",
		      "$text{'mod_ssl_req'},2",
		      "$text{'mod_ssl_optca'},3"));
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

sub edit_SSLExportClientCertificates
{
return (1, $text{'mod_apachessl_exportcert'},
	&choice_input($_[0] ? 1 : 0, "SSLExportClientCertificates", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLExportClientCertificates
{
return $in{'SSLExportClientCertificates'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLSessionCacheTimeout
{
return (1, $text{'mod_apachessl_sesstimeout'},
	&opt_input($_[0]->{'value'}, "SSLSessionCacheTimeout", $text{'mod_ssl_default'}, 6));
}
sub save_SSLSessionCacheTimeout
{
return &parse_opt("SSLSessionCacheTimeout", '^\d+$', $text{'mod_ssl_esesstimeout'});
}

sub edit_SSLCheckClientDN
{
return (1, $text{'mod_apachessl_cdnfile'},
	&opt_input($_[0]->{'value'}, "SSLCheckClientDN", $text{'mod_ssl_default'}, 35).
	&file_chooser_button("SSLCheckClientDN", 0));
}
sub save_SSLCheckClientDN
{
return &parse_opt("SSLCheckClientDN", '\S', $text{'mod_apachessl_ecdnfile'});
}

sub edit_SSLFakeBasicAuth
{
return (1, $text{'mod_apachessl_fake'},
	&choice_input($_[0] ? 1 : 0, "SSLFakeBasicAuth", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLFakeBasicAuth
{
return $in{'SSLFakeBasicAuth'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLUseCRL
{
return (1, $text{'mod_apachessl_usecrl'},
	&choice_input($_[0] ? 1 : 0, "SSLUseCRL", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLUseCRL
{
return $in{'SSLUseCRL'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLCRLCheckAll
{
return (1, $text{'mod_apachessl_crlcheckall'},
	&choice_input($_[0] ? 1 : 0, "SSLCRLCheckAll", "",
		      "$text{'yes'},1", "$text{'no'},0"));
}
sub save_SSLCRLCheckAll
{
return $in{'SSLCRLCheckAll'} ? ( [ "" ] ) : ( [ ] );
}

sub edit_SSLOnNoCRLSetEnv
{
return (1, $text{'mod_apachessl_onnocrl'},
	&opt_input($_[0]->{'value'}, "SSLOnNoCRLSetEnv", $text{'mod_ssl_default'}, 6));
}
sub save_SSLOnNoCRLSetEnv
{
return &parse_choice("SSLOnNoCRLSetEnv");
}

sub edit_SSLOnCRLExpirySetEnv
{
return (1, $text{'mod_apachessl_oncrlexpiry'},
	&opt_input($_[0]->{'value'}, "SSLOnCRLExpirySetEnv", $text{'mod_ssl_default'}, 6));
}
sub save_SSLOnCRLExpirySetEnv
{
return &parse_choice("SSLOnCRLExpirySetEnv");
}

sub edit_SSLOnRevocationSetEnv
{
return (1, $text{'mod_apachessl_onrevocation'},
	&opt_input($_[0]->{'value'}, "SSLOnRevocationSetEnv", $text{'mod_ssl_default'}, 6));
}
sub save_SSLOnRevocationSetEnv
{
return &parse_choice("SSLOnRevocationSetEnv");
}

sub edit_SSLRequiredCiphers
{
local $rows = 3;
local $sw = 0;
local ($o, $i, $l, $rv);
$l = ':'.$_[0]->{'value'}.':';
$rv .= "<table border><tr><td><table cellpadding=0>\n";
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $sw ? '' : '<tr>';
	$o = $mod_apachessl_ciphers[$i];
	$rv .= sprintf "<td><input type=checkbox name=SSLRequiredCiphers_%s value='%s' %s> %s</td>",
			$o, $o, index($l, ":$o:") < 0 ? "" : "checked", $o;
	$rv .= $sw eq $rows-1 ? "</tr>\n" : '';
	$sw = $sw eq $rows-1 ? 0 : $sw+1;
	}
for($i=$sw; $i<=$rows-1; $i++) {
	$rv .= '<td>&nbsp;</td>';
	}
$rv .= $sw eq $rows-1 ? '' : "</tr>\n";
$rv .= '</table></td></tr></table>';
return (2,"$text{'mod_apachessl_requiredcifher'}",$rv);
}
sub save_SSLRequiredCiphers
{
local ($i, $rv);
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $in{"SSLRequiredCiphers_".$mod_apachessl_ciphers[$i]} ? ':'.$mod_apachessl_ciphers[$i] : '';
	}
return $rv ? ( [ substr($rv,1) ] ) : ( [ ] );
}

sub edit_SSLRequireCipher
{
local $rows = 3;
local $sw = 0;
local ($o, $i, $l, $rv);
$l = ' '.$_[0]->{'value'}.' ';
$rv .= "<table border><tr><td><table cellpadding=0>\n";
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $sw ? '' : '<tr>';
	$o = $mod_apachessl_ciphers[$i];
	$rv .= sprintf "<td><input type=checkbox name=SSLRequireCipher_%s value='%s' %s> %s</td>",
			$o, $o, index($l, " $o ") < 0 ? "" : "checked", $o;
	$rv .= $sw eq $rows-1 ? "</tr>\n" : '';
	$sw = $sw eq $rows-1 ? 0 : $sw+1;
	}
for($i=$sw; $i<=$rows-1; $i++) {
	$rv .= '<td>&nbsp;</td>';
	}
$rv .= $sw eq $rows-1 ? '' : "</tr>\n";
$rv .= '</table></td></tr></table>';
return (2,"$text{'mod_apachessl_requirecifher'}",$rv);
}
sub save_SSLRequireCipher
{
local ($i, $rv);
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $in{"SSLRequireCipher_".$mod_apachessl_ciphers[$i]} ? ' '.$mod_apachessl_ciphers[$i] : '';
	}
return $rv ? ( [ substr($rv,1) ] ) : ( [ ] );
}

sub edit_SSLBanCipher{
local $rows = 3;
local $sw = 0;
local ($o, $i, $l, $rv);
$l = ' '.$_[0]->{'value'}.' ';
$rv .= "<table border><tr><td><table cellpadding=0>\n";
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $sw ? '' : '<tr>';
	$o = $mod_apachessl_ciphers[$i];
	$rv .= sprintf "<td><input type=checkbox name=SSLBanCipher_%s value='%s' %s> %s</td>",
			$o, $o, index($l, " $o ") < 0 ? "" : "checked", $o;
	$rv .= $sw eq $rows-1 ? "</tr>\n" : '';
	$sw = $sw eq $rows-1 ? 0 : $sw+1;
	}
for($i=$sw; $i<=$rows-1; $i++) {
	$rv .= '<td>&nbsp;</td>';
	}
$rv .= $sw eq $rows-1 ? '' : "</tr>\n";
$rv .= '</table></td></tr></table>';
return (2,"$text{'mod_apachessl_bancifher'}",$rv);
}
sub save_SSLBanCipher
{
local ($i, $rv);
for($i=0; $i<@mod_apachessl_ciphers; $i++) {
	$rv .= $in{"SSLBanCipher_".$mod_apachessl_ciphers[$i]} ? ' '.$mod_apachessl_ciphers[$i] : '';
	}
return $rv ? ( [ substr($rv,1) ] ) : ( [ ] );
}

#Cipher Suites (from http://www.apache-ssl.org/docs.html)
@mod_apachessl_ciphers = ("IDEA-CBC-SHA",
"NULL-MD5",
"NULL-SHA",
"EXP-RC4-MD5",
"RC4-MD5",
"RC4-SHA",
"EXP-RC2-CBC-MD5",
"IDEA-CBC-MD5",
"EXP-DES-CBC-SHA",
"DES-CBC-SHA",
"DES-CBC3-SHA",
"EXP-DH-DSS-DES-CBC-SHA",
"DH-DSS-DES-CBC-SHA",
"DH-DSS-DES-CBC3-SHA",
"EXP-DH-RSA-DES-CBC-SHA",
"DH-RSA-DES-CBC-SHA",
"DH-RSA-DES-CBC3-SHA",
"EXP-EDH-DSS-DES-CBC-SHA",
"EDH-DSS-DES-CBC-SHA",
"EDH-DSS-DES-CBC3-SHA",
"EXP-EDH-RSA-DES-CBC",
"EDH-RSA-DES-CBC-SHA",
"EDH-RSA-DES-CBC3-SHA",
"EXP-ADH-RC4-MD5",
"ADH-RC4-MD5",
"EXP-ADH-DES-CBC-SHA",
"ADH-DES-CBC-SHA",
"ADH-DES-CBC3-SHA",
"FZA-NULL-SHA",
"FZA-FZA-CBC-SHA",
"FZA-RC4-SHA",
"DES-CFB-M1",
"RC2-CBC-MD5",
"DES-CBC-MD5",
"DES-CBC3-MD5",
"RC4-64-MD5",
"NULL"
);
