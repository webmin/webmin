#!/usr/local/bin/perl
# save_tpriv.cgi
# Save, update or delete table permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'delete'}) {
	# Delete some permissions
	$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
		&error($text{'perms_edb'});
	&execute_sql_logged($master_db,
		"delete from tables_priv where user = '$in{'olduser'}' ".
		"and host = '$in{'oldhost'}' and db = '$in{'olddb'}' ".
		"and table_name = '$in{'oldtable'}'");
	}
else {
	# Validate inputs
	&error_setup($text{'tpriv_err'});
	$in{'table'} || &error($text{'tpriv_etable'});
	$in{'user_def'} || $in{'user'} =~ /^\S+$/ ||
		&error($text{'tpriv_euser'});
	$in{'host_def'} || $in{'host'} =~ /^\S+$/ ||
		&error($text{'tpriv_ehost'});
	$in{'perms1'} =~ s/\0/,/g;
	$in{'perms2'} =~ s/\0/,/g;

	if ($in{'db'}) {
		# Create new table permissions
		$access{'perms'} == 1 || &can_edit_db($in{'db'}) ||
			&error($text{'perms_edb'});
		$sql = "insert into tables_priv (host, db, user, table_name, ".
		       "grantor, table_priv, column_priv) ".
		       "values (?, ?, ?, ?, ?, ?, ?)";
		&execute_sql_logged($master_db, $sql,
			$in{'host_def'} ? '%' : $in{'host'},
			$in{'db'},
			$in{'user_def'} ? '' : $in{'user'},
			$in{'table'}, $config{'login'} || "root",
			$in{'perms1'} || '', $in{'perms2'} || '');
		}
	else {
		# Update existing table permissions
		$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
			&error($text{'perms_edb'});
		$sql = "update tables_priv set host = ?, user = ?, ".
		       "table_name = ?, table_priv = ?, column_priv = ? ".
		       "where host = ? and db = ? and user = ? and ".
		       "table_name = ?";
		&execute_sql_logged($master_db, $sql,
			$in{'host_def'} ? '%' : $in{'host'},
			$in{'user_def'} ? '' : $in{'user'},
			$in{'table'}, $in{'perms1'} || '', $in{'perms2'} || '',
			$in{'oldhost'}, $in{'olddb'},
			$in{'olduser'}, $in{'oldtable'});
		}
	}
&execute_sql_logged($master_db, 'flush privileges');
if ($in{'delete'}) {
	&webmin_log("delete", "tpriv", $in{'oldtable'},
		    { 'user' => $in{'olduser'}, 'host' => $in{'oldhost'},
		      'db' => $in{'olddb'}, 'table' => $in{'oldtable'} } );
	}
elsif ($in{'db'}) {
	&webmin_log("create", "tpriv", $in{'table'},
		    { 'user' => $in{'user_def'} ? '' : $in{'user'},
		      'host' => $in{'host_def'} ? '%' : $in{'host'},
		      'db' => $in{'db'}, 'table' => $in{'table'} } );
	}
else {
	&webmin_log("modify", "tpriv", $in{'table'},
		    { 'user' => $in{'user_def'} ? '' : $in{'user'},
		      'host' => $in{'host_def'} ? '%' : $in{'host'},
		      'db' => $in{'db'}, 'table' => $in{'table'} } );
	}
&redirect("list_tprivs.cgi");

