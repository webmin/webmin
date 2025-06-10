#!/usr/local/bin/perl
# Update local LDAP server LDIF file configuration options

require './ldap-server-lib.pl';
&error_setup($text{'slapd_err'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ReadParse();

&lock_slapd_files();
$conf = &get_ldif_config();

# Validate and store inputs

# Top-level DN
$defdb = &get_default_db();
$in{'suffix'} =~ /=/ || &error($text{'slapd_esuffix'});
&save_ldif_directive($conf, 'olcSuffix', $defdb, $in{'suffix'});

# Admin login
$in{'rootdn'} =~ /=/ || &error($text{'slapd_erootdn'});
&save_ldif_directive($conf, 'olcRootDN', $defdb, $in{'rootdn'});

# Admin password
if (!$in{'rootchange_def'}) {
	$in{'rootchange'} =~ /\S/ || &error($text{'slapd_erootpw'});
	&save_ldif_directive($conf, 'olcRootPW', $defdb,
			     &hash_ldap_password($in{'rootchange'}));
	$config{'pass'} = $in{'rootchange'};
	$save_config = 1;
	}

# Cache sizes
if (!$in{'dbcachesize_def'}) {
	$in{'dbcachesize'} =~ /^\d+$/ || &error($text{'slapd_edbcachesize'});
	&save_ldif_directive($conf, 'olcDbCachesize', $defdb,
			     $in{'dbcachesize'});
	}
else {
	&save_ldif_directive($conf, 'olcDbCachesize', $defdb, undef);
	}

# Size limit
if ($in{'sizelimit_def'}) {
	&save_ldif_directive($conf, 'olcSizeLimit', $defdb, undef);
	}
else {
	$in{'sizelimit'} =~ /^[1-9]\d*$/ || &error($text{'slapd_esizelimit'});
	&save_ldif_directive($conf, 'olcSizeLimit', $defdb, $in{'sizelimit'});
	}

# LDAP protocols
if (&can_get_ldap_protocols()) {
	@newprotos = split(/\0/, $in{'protos'});
	@newprotos || &error($text{'slapd_eprotos'});
	}

# SSL file options
$confdb = &get_config_db();
foreach $s ([ 'olcTLSCertificateFile', 'cert' ],
	    [ 'olcTLSCertificateKeyFile', 'key' ],
	    [ 'olcTLSCACertificateFile', 'ca' ]) {
	if ($in{$s->[1].'_def'}) {
		&save_ldif_directive($conf, $s->[0], $confdb, undef);
		}
	else {
		&valid_pem_file($in{$s->[1]}, $s->[1]) ||
			&error($text{'slapd_e'.$s->[1]});
		&save_ldif_directive($conf, $s->[0], $confdb, $in{$s->[1]});
		}
	}

# Write out the files
&flush_file_lines();
&unlock_slapd_files();
if ($save_config) {
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	}
if (&can_get_ldap_protocols()) {
	$protos = &get_ldap_protocols();
	foreach $p (keys %$protos) {
		$protos->{$p} = 0;
		}
	foreach $p (@newprotos) {
		$protos->{$p} = 1;
		}
	&save_ldap_protocols($protos);
	}
&webmin_log('slapd');

&redirect("");

