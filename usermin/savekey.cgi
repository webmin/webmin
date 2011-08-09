#!/usr/local/bin/perl
# Replace the existing Webmin SSL key

require './usermin-lib.pl';
&ReadParseMime();
&error_setup($text{'savekey_err'});

# Validate inputs
$key = $in{'key'} || $in{'keyfile'};
$key =~ s/\r//g;
$key =~ /BEGIN RSA PRIVATE KEY/ &&
  $key =~ /END RSA PRIVATE KEY/ || &error($text{'savekey_ekey'});
if (!$in{'cert_def'}) {
	# Make sure cert is valid
	$cert = $in{'cert'} || $in{'certfile'};
	$cert =~ s/\r//g;
	$cert =~ /BEGIN CERTIFICATE/ &&
	  $cert =~ /END CERTIFICATE/ || &error($text{'savekey_ecert'});
	}
else {
	# Make sure key contains cert
	$key =~ /BEGIN CERTIFICATE/ &&
	  $key =~ /END CERTIFICATE/ || &error($text{'savekey_ecert2'});
	}
if (!$in{'chain_def'}) {
	# Make sure chained cert is valid
	$chain = $in{'chain'} || $in{'chainfile'};
	$chain =~ s/\r//g;
	$chain =~ /BEGIN CERTIFICATE/ &&
	  $chain =~ /END CERTIFICATE/ || &error($text{'savekey_echain'});
	}

# Save config and key file
&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
$miniserv{'keyfile'} ||= "$config_directory/miniserv.pem";
&lock_file($miniserv{'keyfile'});
&open_tempfile(KEY, ">$miniserv{'keyfile'}");
&print_tempfile(KEY, $key);
&close_tempfile(KEY);
&unlock_file($miniserv{'keyfile'});
if ($in{'cert_def'}) {
	delete($miniserv{'certfile'});
	}
else {
	$miniserv{'certfile'} ||= "$config_directory/miniserv.cert";
	&lock_file($miniserv{'certfile'});
	&open_tempfile(CERT, ">$miniserv{'certfile'}");
	&print_tempfile(CERT, $cert);
	&close_tempfile(CERT);
	&unlock_file($miniserv{'certfile'});
	}
if (!$in{'chain_def'}) {
	$miniserv{'extracas'} = "$config_directory/miniserv.chain"
		if (!$miniserv{'extracas'} || $miniserv{'extracas'} =~ /\s/);
	&lock_file($miniserv{'extracas'});
	&open_tempfile(CERT, ">$miniserv{'extracas'}");
	&print_tempfile(CERT, $chain);
	&close_tempfile(CERT);
	&unlock_file($miniserv{'extracas'});
	}
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

# Tell the user
&ui_print_header(undef, $text{'savekey_title'}, "");

if ($miniserv{'certfile'}) {
	print &text('savekey_done2', "<tt>$miniserv{'keyfile'}</tt>",
				     "<tt>$miniserv{'certfile'}</tt>"),"<p>\n";
	}
else {
	print &text('savekey_done', "<tt>$miniserv{'keyfile'}</tt>"),"<p>\n";
	}
if (!$in{'chain_def'}) {
	print &text('savekey_done3', "<tt>$miniserv{'extracas'}</tt>"),"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

&webmin_log("savekey");
&restart_usermin_miniserv(1);
