#!/usr/local/bin/perl
# Replace the existing Webmin SSL key

require './webmin-lib.pl';
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

# Save config and key file
&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
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
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

# Tell the user
&ui_print_header(undef, $text{'savekey_title'}, "");

if ($miniserv{'certfile'}) {
	print &text('savekey_done2', "<tt>$miniserv{'keyfile'}</tt>",
				     "<tt>$miniserv{'certfile'}</tt>"),"<p>\n";
	}
else {
	print &text('savekey_done', "<tt>$miniserv{'keyfile'}</tt>"),"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

&webmin_log("savekey");
&restart_miniserv(1);
