#!/usr/local/bin/perl
# login.cgi
# Save MySQL login and password

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'login_err'});
$access{'user'} || !$access{'noconfig'} || &error($text{'login_ecannot'});
$in{'login'} || &error($text{'login_elogin'});
$mysql_login = $config{'login'} = $in{'login'};
$mysql_pass = $config{'pass'} = $in{'pass'};
$authstr = &make_authstr();
if (&is_mysql_running() == -1) {
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

