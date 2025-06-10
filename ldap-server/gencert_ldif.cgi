#!/usr/local/bin/perl
# Actually generate the cert, and update the LDIF format config file

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&foreign_require("webmin", "webmin-lib.pl");
&ReadParse();
&error_setup($text{'gencert_err'});
$conf = &get_ldif_config();
$confdb = &get_config_db();

# Work out dest files
if ($in{'dest_def'}) {
	$keyfile = &find_ldif_value("olcTLSCertificateKeyFile", $conf, $confdb);
	$certfile = &find_ldif_value("olcTLSCertificateFile", $conf, $confdb);
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
&save_ldif_directive($conf, "olcTLSCertificateFile", $confdb, $certfile);
&save_ldif_directive($conf, "olcTLSCertificateKeyFile", $confdb, $keyfile);
&flush_file_lines();
&unlock_slapd_files();

&webmin_log("gencert");
&redirect("");

