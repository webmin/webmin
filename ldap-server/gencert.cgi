#!/usr/local/bin/perl
# Actually generate the cert

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
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
$err = &webmin::parse_ssl_key_form(\%in, $keyfile,
				   $certfile eq $keyfile ? undef : $certfile);
&error($err) if ($err);

# Make readable by LDAP user
&set_ownership_permissions($config{'ldap_user'}, undef, undef,
			   $keyfile, $certfile);

# Update config to use them
&lock_slapd_files();
&save_directive($conf, "TLSCertificateFile", $certfile);
&save_directive($conf, "TLSCertificateKeyFile", $keyfile);
&flush_file_lines($config{'config_file'});
&unlock_slapd_files();

&webmin_log("gencert");
&redirect("");

