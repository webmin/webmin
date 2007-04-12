#!/usr/local/bin/perl
# save_user.cgi
# Create, update or delete a postgres user

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'user_ecannot'});
&error_setup($text{'user_err'});

if ($in{'delete'}) {
	# just delete the user
	&execute_sql_logged($config{'basedb'}, "drop user \"$in{'user'}\"");
	&webmin_log("delete", "user", $in{'user'});
	}
else {
	# parse inputs
	$version = &get_postgresql_version();
	if ($in{'pass_def'} == 0) {
		$in{'pass'} =~ /^\S+$/ || &error($text{'user_epass'});
		$sql .= $version >= 7 ? " with password '$in{'pass'}'"
				      : " with password $in{'pass'}";
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
	if ($in{'other'}) {
		$sql .= " createuser";
		}
	else {
		$sql .= " nocreateuser";
		}
	if (!$in{'until_def'}) {
		$sql .= " valid until '$in{'until'}'";
		}
	if ($in{'new'}) {
		$in{'name'} =~ /^\S+$/ || &error($text{'user_ename'});
		&execute_sql_logged($config{'basedb'},
				    "create user \"$in{'name'}\" $sql");
		&webmin_log("create", "user", $in{'name'});
		}
	else {
		&execute_sql_logged($config{'basedb'},
				    "alter user \"$in{'user'}\" $sql");
		if (&get_postgresql_version() >= 7.4 &&
		    $in{'name'} ne $in{'user'}) {
			# Rename too
			&execute_sql_logged($config{'basedb'},
		    		"alter user \"$in{'user'}\" ".
				"rename to \"$in{'name'}\"");
			}
		&webmin_log("modify", "user", $in{'user'});
		}
	}
&redirect("list_users.cgi");

