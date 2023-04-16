#!/usr/local/bin/perl
# Update local LDAP server configuration options

require './ldap-server-lib.pl';
&error_setup($text{'slapd_err'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ReadParse();

&lock_slapd_files();
$conf = &get_config();

# Validate and store inputs

# Top-level DN
$in{'suffix'} =~ /=/ || &error($text{'slapd_esuffix'});
&save_directive($conf, 'suffix', $in{'suffix'});

# Admin login
$in{'rootdn'} =~ /=/ || &error($text{'slapd_erootdn'});
&save_directive($conf, 'rootdn', $in{'rootdn'});

# Admin password
if (!$in{'rootchange_def'}) {
	$in{'rootchange'} =~ /\S/ || &error($text{'slapd_erootpw'});
	&save_directive($conf, 'rootpw',
			&hash_ldap_password($in{'rootchange'}));
	$config{'pass'} = $in{'rootchange'};
	$save_config = 1;
	}

# Cache sizes
if (!$in{'cachesize_def'}) {
	$in{'cachesize'} =~ /^\d+$/ || &error($text{'slapd_ecachesize'});
	&save_directive($conf, 'cachesize', $in{'cachesize'});
	}
else {
	&save_directive($conf, 'cachesize', undef);
	}
if (!$in{'dbcachesize_def'}) {
	$in{'dbcachesize'} =~ /^\d+$/ || &error($text{'slapd_edbcachesize'});
	&save_directive($conf, 'dbcachesize', $in{'dbcachesize'});
	}
else {
	&save_directive($conf, 'dbcachesize', undef);
	}

# Access control options
@allow = split(/\0/, $in{'allow'});
&save_directive($conf, 'allow', @allow ? \@allow : undef);

# Size and time limits
if ($in{'sizelimit_def'}) {
	&save_directive($conf, 'sizelimit', undef);
	}
else {
	$in{'sizelimit'} =~ /^[1-9]\d*$/ || &error($text{'slapd_esizelimit'});
	&save_directive($conf, 'sizelimit', $in{'sizelimit'});
	}
if ($in{'timelimit_def'}) {
	&save_directive($conf, 'timelimit', undef);
	}
else {
	$in{'timelimit'} =~ /^[1-9]\d*$/ || &error($text{'slapd_etimelimit'});
	&save_directive($conf, 'timelimit', $in{'timelimit'});
	}

# LDAP protocols
if (&can_get_ldap_protocols()) {
	@newprotos = split(/\0/, $in{'protos'});
	@newprotos || &error($text{'slapd_eprotos'});
	}

# SSL file options
foreach $s ([ 'TLSCertificateFile', 'cert' ],
	    [ 'TLSCertificateKeyFile', 'key' ],
	    [ 'TLSCACertificateFile', 'ca' ]) {
	if ($in{$s->[1].'_def'}) {
		&save_directive($conf, $s->[0], undef);
		}
	else {
		&valid_pem_file($in{$s->[1]}, $s->[1]) ||
			&error($text{'slapd_e'.$s->[1]});
		&save_directive($conf, $s->[0], $in{$s->[1]});
		}
	}

# Write out the files
&flush_file_lines($config{'config_file'});
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

