#!/usr/local/bin/perl
# save_user.cgi
# Create, update or delete a postgres user

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'user_ecannot'});
&error_setup($text{'user_err'});

if ($in{'delete'}) {
	# just delete the user
	$main::disable_postgresql_escaping = 1;
	&execute_sql_logged($config{'basedb'}, "drop user \"$in{'user'}\"");
	&webmin_log("delete", "user", $in{'user'});
	}
else {
	# parse inputs
	$version = &get_postgresql_version();
	if ($in{'ppass_def'} == 0) {
		$in{'ppass'} =~ /^\S+$/ || &error($text{'user_epass'});
		$sql .= $version >= 7 ? " with password '$in{'ppass'}'"
				      : " with password $in{'ppass'}";
		}
	elsif ($in{'pass_def'} == 1) {
		$sql .= " with password ''";
		}
	if ($in{'db'}) {
		$sql .= " createdb";
		}
	else {
		$sql .= " nocreatedb";
		}
	if (&get_postgresql_version() < 9.5) {
		if ($in{'other'}) {
			$sql .= " createuser";
			}
		else {
			$sql .= " nocreateuser";
			}
		}
	if (!$in{'until_def'}) {
		$sql .= " valid until '$in{'until'}'";
		}
	if ($in{'new'}) {
		$in{'pname'} =~ /^\S+$/ || &error($text{'user_ename'});
		&execute_sql_logged($config{'basedb'},
				    "create user \"$in{'pname'}\" $sql");
		&webmin_log("create", "user", $in{'pname'});
		}
	else {
		&execute_sql_logged($config{'basedb'},
				    "alter user \"$in{'user'}\" $sql");
		if (&get_postgresql_version() >= 7.4 &&
		    $in{'pname'} ne $in{'user'}) {
			# Rename too
			&execute_sql_logged($config{'basedb'},
		    		"alter user \"$in{'user'}\" ".
				"rename to \"$in{'pname'}\"");
			}
		&webmin_log("modify", "user", $in{'user'});
		}
	}
&redirect("list_users.cgi");

