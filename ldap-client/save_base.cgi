#!/usr/local/bin/perl
# Save the LDAP search base

require './ldap-client-lib.pl';
&error_setup($text{'base_err'});
&ReadParse();

&lock_file(&get_ldap_config_file());
$conf = &get_config();

# Validate and save inputs, starting with global base
$in{'base'} =~ /\S/ || &error($text{'base_ebase'});
&save_directive($conf, "base", $in{'base'});

# Save scope
&save_directive($conf, "scope", $in{'scope'} || undef);

# Save time limit
if ($in{'timelimit_def'}) {
	&save_directive($conf, "timelimit", undef);
	}
else {
	$in{'timelimit'} =~ /^\d+$/ || &error($text{'base_etimelimit'});
	&save_directive($conf, "timelimit", $in{'timelimit'});
	}

# Save per-service bases
foreach $b (@base_types) {
	if ($in{"base_".$b."_def"}) {
		&save_directive($conf, "nss_base_".$b, undef);
		}
	else {
		local $base = $in{"base_".$b};
		$base =~ /\S/ || &error($text{'base_e'.$b});
		if ($in{'scope_'.$b}) {
			$base .= "?".$in{'scope_'.$b};
			}
		if ($in{'filter_'.$b}) {
			$base .= "?" if ($in{'scope_'.$b});
			$file .= "?".$in{'filter_'.$b};
			}
		&save_directive($conf, "nss_base_".$b, $base);
		}
	}

# Write out config
&flush_file_lines();
&unlock_file(&get_ldap_config_file());

&webmin_log("base");
&redirect("");

