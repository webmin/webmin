#!/usr/local/bin/perl
# Save authentication options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text, %config, %in);
&ReadParse();
&lock_file($config{'initiator_file'});
&lock_file($config{'config_file'});
my $conf = &get_iscsi_config();
&error_setup($text{'auth_err'});

# Authentication method
&save_directive($conf, "node.session.auth.authmethod", $in{'method'});

# Login and password to iSCSI server
if ($in{'username_def'}) {
	&save_directive($conf, "node.session.auth.username", undef);
	&save_directive($conf, "node.session.auth.password", undef);
	}
else {
	$in{'username'} =~ /\S/ || &error($text{'auth_eusername'});
	$in{'password'} =~ /\S/ || &error($text{'auth_epassword'});
	&save_directive($conf, "node.session.auth.username", $in{'username'});
	&save_directive($conf, "node.session.auth.password", $in{'password'});
	}

# Login and password by the iSCSI server to the client
if ($in{'username_in_def'}) {
	&save_directive($conf, "node.session.auth.username_in", undef);
	&save_directive($conf, "node.session.auth.password_in", undef);
	}
else {
	$in{'username_in'} =~ /\S/ || &error($text{'auth_eusername_in'});
	$in{'password_in'} =~ /\S/ || &error($text{'auth_epassword_in'});
	&save_directive($conf, "node.session.auth.username_in",
			$in{'username_in'});
	&save_directive($conf, "node.session.auth.password_in",
			$in{'password_in'});
	}

# Authentication method
&save_directive($conf, "discovery.sendtargets.auth.authmethod", $in{'dmethod'});

# Discovery login and password to iSCSI server
if ($in{'dusername_def'}) {
	&save_directive($conf, "discovery.sendtargets.auth.username", undef);
	&save_directive($conf, "discovery.sendtargets.auth.password", undef);
	}
else {
	$in{'dusername'} =~ /\S/ || &error($text{'auth_edusername'});
	$in{'dpassword'} =~ /\S/ || &error($text{'auth_edpassword'});
	&save_directive($conf, "discovery.sendtargets.auth.username",
			$in{'dusername'});
	&save_directive($conf, "discovery.sendtargets.auth.password",
			$in{'dpassword'});
	}

# Discovery login and password by the iSCSI server to the client
if ($in{'dusername_in_def'}) {
	&save_directive($conf, "discovery.sendtargets.auth.username_in", undef);
	&save_directive($conf, "discovery.sendtargets.auth.password_in", undef);
	}
else {
	$in{'dusername_in'} =~ /\S/ || &error($text{'auth_edusername_in'});
	$in{'dpassword_in'} =~ /\S/ || &error($text{'auth_edpassword_in'});
	&save_directive($conf, "discovery.sendtargets.auth.username_in",
			$in{'dusername_in'});
	&save_directive($conf, "discovery.sendtargets.auth.password_in",
			$in{'dpassword_in'});
	}

# Initiator name
if ($in{'newname'}) {
	my $gen = &generate_initiator_name();
	$gen || &error($text{'auth_egen'});
	&save_initiator_name($gen);
	}
elsif ($in{'name'} ne &get_initiator_name()) {
	# Validate and save name
	$in{'name'} =~ /^[a-z0-9\.\-\:]+$/ && length($in{'name'}) <= 223 ||
		&error($text{'auth_ename'});
	&save_initiator_name($in{'name'});
	}

&flush_file_lines($config{'targets_file'});
&unlock_file($config{'config_file'});
&unlock_file($config{'initiator_file'});
&webmin_log("auth");
&redirect("");

