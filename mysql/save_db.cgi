#!/usr/local/bin/perl
# save_db.cgi
# Save, create or delete a db table record

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'delete'}) {
	# Delete some database
	$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
		&error($text{'perms_edb'});
	&execute_sql_logged($master_db,
		"delete from db where user = '$in{'olduser'}' ".
		"and host = '$in{'oldhost'}' and db = '$in{'olddb'}'");
	}
else {
	# Validate inputs
	&error_setup($text{'db_err'});
	$in{'user_def'} || $in{'user'} =~ /^\S+$/ ||
		&error($text{'db_euser'});
	$in{'host'} < 2 || $in{'host'} =~ /^\S+$/ ||
		&error($text{'db_ehost'});
	if ($access{'perms'} == 2 && $access{'dbs'} ne '*') {
		$db = $in{'dbs'};
		}
	else {
		$db = $in{'db_def'} == 1 ? "" :
		      $in{'db_def'} == 2 ? $in{'dbs'} : $in{'db'};
		$db =~ /^\S*$/ || &error($text{'db_edb'});
		}
	if ($access{'perms'} == 2) {
		$in{'new'} || &can_edit_db($in{'olddb'}) ||
			&error($text{'perms_edb'});
		&can_edit_db($db) || &error($text{'perms_edb'});
		}

	%perms = map { $_, 1 } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'db');
	@pfields = map { $_->[0] } &priv_fields('db');
	$host = $in{'host_mode'} == 0 ? '' :
		$in{'host_mode'} == 1 ? '%' : $in{'host'};
	$user = $in{'user_def'} ? '' : $in{'user'};
	if ($in{'new'}) {
		# Create a new db
		$sql = "insert into db (host, db, user, ".
                       join(", ", @pfields).
                       ") values (?, ?, ?, ". 
                       join(", ", map { "?" } @pfields).")";
                &execute_sql_logged($master_db, $sql,
                        $host, $db, $user,
                        (map { $perms{$_} ? 'Y' : 'N' } @pfields));
		}
	else {
		# Update existing db
		$sql = "update db set host = ?, db = ?, user = ?, ".
		       join(", ",map { "$_ = ?" } @pfields).
		       " where host = ? and db = ? and user = ?";
		&execute_sql_logged($master_db, $sql,
			$host, $db, $user,
			(map { $perms{$_} ? 'Y' : 'N' } @pfields),
			$in{'oldhost'}, $in{'olddb'}, $in{'olduser'});
		}
	}
&execute_sql_logged($master_db, 'flush privileges');
if ($in{'delete'}) {
	&webmin_log("delete", "perm", $in{'olddb'},
		    { 'db' => $in{'olddb'},
		      'host' => $in{'oldhost'},
		      'user' => $in{'olduser'} } );
	}
elsif ($in{'new'}) {
	&webmin_log("create", "perm", $in{'db_def'} ? '' : $in{'db'},
		    { 'db' => $db,
		      'host' => $in{'host_mode'}<2 ? '' : $in{'host'},
		      'user' => $in{'user_def'} ? '' : $in{'user'} } );
	}
else {
	&webmin_log("modify", "perm", $in{'db_def'} ? '' : $in{'db'},
		    { 'db' => $db,
		      'host' => $in{'host_mode'}<2 ? '' : $in{'host'},
		      'user' => $in{'user_def'} ? '' : $in{'user'} } );
	}
&redirect("list_dbs.cgi");

