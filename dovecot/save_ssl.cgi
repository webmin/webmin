#!/usr/local/bin/perl
# Update SSL options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'ssl_err'});
$conf = &get_config();
&lock_dovecot_files($conf);

# Save SSL cert
$in{'cert_def'} || -r $in{'cert'} || $in{'cert'} =~ /^[<>\|]/ ||
	&error($text{'ssl_ecert'});
if (&version_atleast("2.4")) {
	&save_directive($conf, "ssl_server_cert_file",
		        $in{'cert_def'} ? undef : $in{'cert'}, "");
	}
elsif (&find_value("ssl_cert", $conf, 2) || &version_atleast("2.2")) {
	$in{'cert'} = "<".$in{'cert'} if ($in{'cert'} =~ /^\//);
	&save_directive($conf, "ssl_cert",
		        $in{'cert_def'} ? undef : $in{'cert'}, "");
	}
else {
	&save_directive($conf, "ssl_cert_file",
		        $in{'cert_def'} ? undef : $in{'cert'});
	}

# Save SSL key
$in{'key_def'} || -r $in{'key'} || $in{'key'} =~ /^[<>\|]/ ||
	&error($text{'ssl_ekey'});
if (&version_atleast("2.4")) {
	&save_directive($conf, "ssl_server_key_file",
		        $in{'key_def'} ? undef : $in{'key'}, "");
	}
elsif (&find_value("ssl_key", $conf, 2) || &version_atleast("2.2")) {
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
if (&version_atleast("2.4")) {
	&save_directive($conf, "ssl_server_ca_file",
		        $in{'ca_def'} ? undef : $in{'ca'}, "");
	}
elsif (&find_value("ssl_ca", $conf, 2) || &version_atleast("2.2")) {
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
&save_directive($conf,
	&version_atleast("2.4")
		? "ssl_server_key_password"
		: "ssl_key_password",
	$in{'pass_def'} ? undef : $in{'pass'});

# Save SSL parameter regeneration time
if (&version_below("2.4")) {
	$in{'regen_def'} || $in{'regen'} =~ /^\d+$/ ||
		&error($text{'ssl_eregen'});
	&save_directive($conf, "ssl_parameters_regenerate",
			$in{'regen_def'} ? undef : $in{'regen'});
	}

# Save plaintext password setting
if (&find_value("auth_allow_cleartext", $conf, 2)) {
	&save_directive($conf, "auth_allow_cleartext",
			$in{'plain'} ? $in{'plain'} : undef);
	}
else {
	&save_directive($conf, "disable_plaintext_auth",
			$in{'plain'} ? $in{'plain'} : undef);
	}

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("ssl");
&redirect("");

