#!/usr/local/bin/perl
# Save the LDAP server to connect to

require './ldap-client-lib.pl';
&error_setup($text{'server_err'});
&ReadParse();

&lock_file(&get_ldap_config_file());
$conf = &get_config();

# Validate and save inputs, starting with filter
if ($in{'filter_def'}) {
	&save_directive($conf, "pam_filter", undef);
	}
else {
	$in{'filter'} =~ /\S/ || &error($text{'pam_efilter'});
	&save_directive($conf, "pam_filter", $in{'filter'});
	}

# Save login attribute
if ($in{'login_def'}) {
	&save_directive($conf, "pam_login_attribute", undef);
	}
else {
	$in{'login'} =~ /^\S+$/ || &error($text{'pam_elogin'});
	&save_directive($conf, "pam_login_attribute", $in{'login'});
	}

# Save group DN
if ($in{'groupdn_def'}) {
	&save_directive($conf, "pam_groupdn", undef);
	}
else {
	$in{'groupdn'} =~ /\S/ || &error($text{'pam_egroupdn'});
	&save_directive($conf, "pam_groupdn", $in{'groupdn'});
	}

# Save group member attribute
if ($in{'member_def'}) {
	&save_directive($conf, "pam_member_attribute", undef);
	}
else {
	$in{'member'} =~ /^\S+$/ || &error($text{'pam_emember'});
	&save_directive($conf, "pam_member_attribute", $in{'member'});
	}

# Save password mode
&save_directive($conf, "pam_password", $in{'password'} || undef);

# Write out config
&flush_file_lines();
&unlock_file(&get_ldap_config_file());

&webmin_log("pam");
&redirect("");

