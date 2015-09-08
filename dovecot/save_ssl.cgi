#!/usr/local/bin/perl
# Update SSL options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});
$conf = &get_config();
&lock_dovecot_files($conf);

# Save SSL cert and key
$in{'cert_def'} || -r $in{'cert'} || $in{'cert'} =~ /^[<>\|]/ ||
	&error($text{'ssl_ecert'});
if (&find_value("ssl_cert", $conf, 2)) {
	$in{'cert'} = "<".$in{'cert'} if ($in{'cert'} =~ /^\//);
	&save_directive($conf, "ssl_cert",
		        $in{'cert_def'} ? undef : $in{'cert'}, "");
	}
else {
	&save_directive($conf, "ssl_cert_file",
		        $in{'cert_def'} ? undef : $in{'cert'});
	}
$in{'key_def'} || -r $in{'key'} || $in{'key'} =~ /^[<>\|]/ ||
	&error($text{'ssl_ekey'});
if (&find_value("ssl_key", $conf, 2)) {
	$in{'key'} = "<".$in{'key'} if ($in{'key'} =~ /^\//);
	&save_directive($conf, "ssl_key",
		        $in{'key_def'} ? undef : $in{'key'}, "");
	}
else {
	&save_directive($conf, "ssl_key_file",
		        $in{'key_def'} ? undef : $in{'key'});
	}

# Save SSL CA cert
$in{'ca_def'} || -r $in{'ca'} || $in{'ca'} =~ /^[<>\|]/ ||
	&error($text{'ssl_eca'});
if (&find_value("ssl_ca", $conf, 2)) {
	$in{'ca'} = "<".$in{'ca'} if ($in{'ca'} =~ /^\//);
	&save_directive($conf, "ssl_ca",
		        $in{'ca_def'} ? undef : $in{'ca'}, "");
	}
else {
	&save_directive($conf, "ssl_ca_file",
		        $in{'ca_def'} ? undef : $in{'ca'});
	}

# Save SSL key password
$in{'pass_def'} || $in{'pass'} =~ /\S/ || &error($text{'ssl_epass'});
&save_directive($conf, "ssl_key_password",
		$in{'pass_def'} ? undef : $in{'pass'});

$in{'regen_def'} || $in{'regen'} =~ /^\d+$/ || &error($text{'ssl_eregen'});
&save_directive($conf, "ssl_parameters_regenerate",
		$in{'regen_def'} ? undef : $in{'regen'});

&save_directive($conf, "disable_plaintext_auth",
		$in{'plain'} ? $in{'plain'} : undef);

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("ssl");
&redirect("");

