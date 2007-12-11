#!/usr/local/bin/perl
# Actually generate the cert

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&foreign_require("webmin", "webmin-lib.pl");
&ReadParse();
&error_setup($text{'gencert_err'});
$conf = &get_config();

# Work out dest files
if ($in{'dest_def'}) {
	$keyfile = &find_value("TLSCertificateKeyFile", $conf);
	$certfile = &find_value("TLSCertificateFile", $conf);
	}
else {
	# In some dir
	-d $in{'dest'} || &error($text{'gencert_edest'});
	$keyfile = $in{'dest'}."/ldap.key";
	$certfile = $in{'dest'}."/ldap.cert";
	}

# Do it
$err = &webmin::parse_ssl_key_form(\%in, $keyfile, $certfile);
&error($err) if ($err);

# Update config to use them
&lock_file($config{'config_file'});
&save_directive($conf, "TLSCertificateFile", $certfile);
&save_directive($conf, "TLSCertificateKeyFile", $keyfile);
&flush_file_lines($config{'config_file'});
&unlock_file($config{'config_file'});

&webmin_log("gencert");
&redirect("");

