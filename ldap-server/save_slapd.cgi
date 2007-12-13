#!/usr/local/bin/perl
# Update local LDAP server configuration options

require './ldap-server-lib.pl';
&error_setup($text{'slapd_err'});
$access{'slapd'} || &error($text{'slapd_ecannot'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ReadParse();

&lock_file($config{'config_file'});
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
	$crypt = &unix_crypt($in{'rootchange'}, substr(time(), -2));
	&save_directive($conf, 'rootpw', "{crypt}".$crypt);
	$config{'pass'} = $in{'rootchange'};
	$save_config = 1;
	}

# Cache sizes
$in{'cachesize'} =~ /^\d+$/ || &error($text{'slapd_ecachesize'});
&save_directive($conf, 'cachesize', $in{'cachesize'});
$in{'dbcachesize'} =~ /^\d+$/ || &error($text{'slapd_edbcachesize'});
&save_directive($conf, 'dbcachesize', $in{'dbcachesize'});

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
&unlock_file($config{'config_file'});
if ($save_config) {
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	}
&webmin_log('slapd');

&redirect("");

