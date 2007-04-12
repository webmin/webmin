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

	map { $perms[$_]++ } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'db');
	if ($in{'new'}) {
		# Create a new db
		for($i=3; $i<=&db_priv_cols()+3-1; $i++) {
			push(@yesno, $perms[$i] ? "'Y'" : "'N'");
			}
		$sql = sprintf "insert into db (%s) values ('%s', '%s', '%s', %s)",
			join(",", map { $desc[$_]->{'field'} } (0 .. &db_priv_cols()+3-1)),
			$in{'host_mode'} == 0 ? '' :
			$in{'host_mode'} == 1 ? '%' : $in{'host'},
			$db, $in{'user_def'} ? '' : $in{'user'},
			join(",", @yesno);
		}
	else {
		# Update existing user
		for($i=3; $i<=&db_priv_cols()+3-1; $i++) {
			push(@yesno, $desc[$i]->{'field'}."=".
				     ($perms[$i] ? "'Y'" : "'N'"));
			}
		$sql = sprintf "update db set user = '%s', host = '%s', ".
			       "db = '%s', %s where user = '%s' and ".
			       "host = '%s' and db = '%s'",
			$in{'user_def'} ? '' : $in{'user'},
			$in{'host_mode'} == 0 ? '' :
			$in{'host_mode'} == 1 ? '%' : $in{'host'},
			$db, join(" , ", @yesno),
			$in{'olduser'}, $in{'oldhost'}, $in{'olddb'};
		}
	&execute_sql_logged($master_db, $sql);
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

