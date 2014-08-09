#!/usr/local/bin/perl
# Enable the LDAP client daemon at boot or not

require './ldap-client-lib.pl';
&ReadParse();

&foreign_require("init");
my $starting = &init::action_status($config{'init_name'});
if ($starting == 1 && $in{'boot'}) {
	&fix_ldap_authconfig();
	&init::enable_at_boot($config{'init_name'});
	&webmin_log("atboot");
	}
elsif ($starting == 2 && !$in{'boot'}) {
	# Disable at boot
	&init::disable_at_boot($config{'init_name'});
	&webmin_log("delboot");
	}

&redirect("");

