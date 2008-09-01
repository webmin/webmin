#!/usr/local/bin/perl
# Update SSL options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});
&lock_file($config{'dovecot_config'});
$conf = &get_config();

# Save SSL cert and key
$in{'cert_def'} || -r $in{'cert'} || &error($text{'ssl_ecert'});
$in{'key_def'} || -r $in{'key'} || &error($text{'ssl_ekey'});
&save_directive($conf, "ssl_cert_file", $in{'cert_def'} ? undef : $in{'cert'});
&save_directive($conf, "ssl_key_file", $in{'key_def'} ? undef : $in{'key'});

# Save SSL CA cert
$in{'ca_def'} || -r $in{'ca'} || &error($text{'ssl_eca'});
&save_directive($conf, "ssl_ca_file", $in{'ca_def'} ? undef : $in{'ca'});

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
&unlock_file($config{'dovecot_config'});
&webmin_log("ssl");
&redirect("");

