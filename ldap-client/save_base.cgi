#!/usr/local/bin/perl
# Save the LDAP search base

require './ldap-client-lib.pl';
&error_setup($text{'base_err'});
&ReadParse();

&lock_file(&get_ldap_config_file());
$conf = &get_config();

# Validate and save inputs, starting with global base
$in{'base'} =~ /\S/ || &error($text{'base_ebase'});
@bases = ( $in{'base'} );

# Save scope
@scopes = ( );
push(@scopes, $in{'scope'}) if ($in{'scope'});

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
	local $base;
	if ($in{"base_".$b."_def"}) {
		$base = undef;
		}
	else {
		$base = $in{"base_".$b};
		$base =~ /\S/ || &error($text{'base_e'.$b});
		if ($in{'scope_'.$b}) {
			if (&get_ldap_client() eq "nss") {
				# Scope is appended to the base
				$base .= "?".$in{'scope_'.$b};
				}
			else {
				# Scopes are saved separately
				push(@scopes, $b." ".$in{'scope_'.$b});
				}
			}
		if ($in{'filter_'.$b}) {
			if (&get_ldap_client() eq "nss") {
				# Filter is appended to the base
				$base .= "?" if ($in{'scope_'.$b});
				$file .= "?".$in{'filter_'.$b};
				}
			else {
				# Filters are saved separately
				push(@filters, $b." ".$in{'filter_'.$b});
				}
			}
		}
	if (&get_ldap_client() eq "nss") {
		# Update DB-specific directive
		&save_directive($conf, "nss_base_".$b, $base);
		}
	else {
		# Add to list of base directives to save
		push(@bases, $b." ".$base) if ($base);
		}
	}

# Save all base, scope and filter directives
&save_directive($conf, "base", \@bases);
&save_directive($conf, "scope", \@scopes);
if (&get_ldap_client() eq "nslcd") {
	&save_directive($conf, "filter", \@filters);
	}

# Write out config
&flush_file_lines();
&unlock_file(&get_ldap_config_file());

&webmin_log("base");
&redirect("");

