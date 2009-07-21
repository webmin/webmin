#!/usr/local/bin/perl
# Add lookaside and trusted key records for ICS's DLV zone

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'trusted_ecannot'});
&error_setup($text{'trusted_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
$parent = &get_config_parent();
$conf = $parent->{'members'};
$options = &find("options", $conf);

# Enable DNSSEC
&save_directive($options, "dnssec-enable",
		[ { 'name' => 'dnssec-enable',
		    'values' => [ 'yes' ] } ], 1);
if (&supports_dnssec_client() == 2) {
	&save_directive($options, "dnssec-validation",
			[ { 'name' => 'dnssec-validation',
			    'values' => [ 'yes' ] } ], 1);
	}

# Lookaside
&save_directive($options, "dnssec-lookaside", 
		[ { 'name' => 'dnssec-lookaside',
		    'values' => [ ".", "trust-anchor", $dnssec_dlv_zone ] } ],
		1);

# ICS's key
$trusted = &find("trusted-keys", $conf);
if (!$trusted) {
	# Need to create block
	$trusted = { 'name' => 'trusted-keys',
		     'type' => 1,
		     'members' => [ ] };
	&save_directive($parent, "trusted-keys", [ $trusted ]);
	}
&save_directive($trusted, [ ],
		[ { 'name' => $dnssec_dlv_zone,
		    'values' => \@dnssec_dlv_key } ], 1);

&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&restart_bind();
&webmin_log("trusted");
&redirect("");
