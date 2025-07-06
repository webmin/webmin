#!/usr/local/bin/perl
# change_ssl.cgi
# Enable or disable SSL support

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
$sslcurr = $miniserv{'ssl'};
$miniserv{'ssl'} = $in{'ssl'};
$miniserv{'ssl_enforce'} = int($in{'ssl_enforce'});
$miniserv{'ssl_hsts'} = $miniserv{'ssl_enforce'} == 2 ? 1 : 0;
&validate_key_cert($in{'key'}, $in{'cert_def'} ? undef : $in{'cert'});
$miniserv{'keyfile'} = $in{'key'};
$miniserv{'certfile'} = $in{'cert_def'} ? undef : $in{'cert'};
$miniserv{'no_sslcompression'} = !$in{'ssl_compression'};
$miniserv{'ssl_honorcipherorder'} = $in{'ssl_honorcipherorder'};
if ($in{'version_def'}) {
	delete($miniserv{'ssl_version'});
	}
else {
	$in{'version'} =~ /^\d+$/ || &error($text{'ssl_eversion'});
	$miniserv{'ssl_version'} = $in{'version'};
	}
$miniserv{'no_ssl2'} = $in{'no_ssl2'};
$miniserv{'no_ssl3'} = $in{'no_ssl3'};
$miniserv{'no_tls1'} = $in{'no_tls1'};
$miniserv{'no_tls1_1'} = $in{'no_tls1_1'};
$miniserv{'no_tls1_2'} = $in{'no_tls1_2'};
if ($in{'cipher_list_def'} == 1) {
	delete($miniserv{'ssl_cipher_list'});
	}
elsif ($in{'cipher_list_def'} == 2) {
	$miniserv{'ssl_cipher_list'} = $strong_ssl_ciphers;
	}
elsif ($in{'cipher_list_def'} == 3) {
	# Check for PFS support
	eval "use Net::SSLeay";
	$Net::SSLeay::VERSION >= 1.57 ||
		&error(&text('ssl_epfsversion', $Net::SSLeay::VERSION, 1.57));

	$miniserv{'ssl_cipher_list'} = $pfs_ssl_ciphers;
	$miniserv{'dhparams_file'} ||= "$config_directory/dhparams.pem";
	if (!-r $miniserv{'dhparams_file'}) {
		# Generate file needed for PFS
		my $out = &backquote_command(
			"openssl dhparam -out ".
			quotemeta($miniserv{'dhparams_file'})." 2048 2>&1");
		if ($?) {
			&error(&text('ssl_edhparams',
				     "<pre>".&html_escape($out)."</pre>"));
			}
		&set_ownership_permissions(
			undef, undef, 700, $miniserv{'dhparams_file'});
		}
	}
else {
	$in{'cipher_list'} =~ /^\S+$/ || &error($text{'ssl_ecipher_list'});
	$miniserv{'ssl_cipher_list'} = $in{'cipher_list'};
	}
$miniserv{'cipher_list_def'} = $in{'cipher_list_def'};
foreach $ec (split(/[\r\n]+/, $in{'extracas'})) {
	-r $ec && !-d $ec || &error(&text('ssl_eextraca', $ec));
	push(@extracas, $ec);
	}
$miniserv{'extracas'} = join("\t", @extracas);
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

$SIG{'TERM'} = 'IGNORE';	# stop process from being killed by restart
&restart_miniserv();
&webmin_log("ssl", undef, undef, \%in);

if (!$miniserv{'ssl_hsts'}) {
	# Tell browser to unset HSTS policy to make non-SSL URL work 
	print "Strict-Transport-Security: max-age=0;\n";
	}

$url = ($in{'ssl'} ? "https://" : "http://") .
            "$ENV{'SERVER_NAME'}:$miniserv{'port'}";
if ($sslcurr != $miniserv{'ssl'}) {
	%tinfo = &get_theme_info($current_theme);
	if ($tinfo{'spa'} && $tinfo{'nomodcall'}) {
		$url .= "@{[&get_webprefix()]}/webmin/?$tinfo{'nomodcall'}";
		}
	&ui_print_header(undef, $text{'ssl_title'}, "", undef, undef, 1);
	print $text{'ssl_redirect'},"<br>\n";
	print "<script>\n";
	print "top.location = '$url';\n";
	print "</script>\n";
	&ui_print_footer();
	}
else {
	&redirect("");
	}
