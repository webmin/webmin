#!/usr/local/bin/perl
# login.cgi
# Save PostgreSQL login and password

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'login_err'});
$access{'user'} || !$access{'noconfig'} || &error($text{'login_ecannot'});
$in{'login'} || &error($text{'login_elogin'});
$postgres_login = $config{'login'} = $in{'login'};
$postgres_pass = $config{'pass'} = $in{'pass'};
if (!$access{'user'}) {
	$postgres_sameunix = $config{'sameunix'} = $in{'sameunix'};
	}
if (&is_postgresql_running() == -1) {
	&error($text{'login_epass'});
	}
if ($access{'user'}) {
	# Update this user's ACL
	$access{'user'} = $in{'login'};
	$access{'pass'} = $in{'pass'};
	&save_module_acl(\%access);
	}
else {
	# Update global login
	&write_file("$module_config_directory/config", \%config);
	chmod(0700, "$module_config_directory/config");
	}
&redirect("");

