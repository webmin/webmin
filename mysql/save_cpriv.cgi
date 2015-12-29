#!/usr/local/bin/perl
# save_cpriv.cgi
# Save, update or delete field permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'delete'}) {
	# Delete some permissions
	$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
		&error($text{'perms_edb'});
	&execute_sql_logged($master_db,
		"delete from columns_priv where user = '$in{'olduser'}' ".
		"and host = '$in{'oldhost'}' and db = '$in{'olddb'}' ".
		"and table_name = '$in{'oldtable'}' ".
		"and column_name = '$in{'oldfield'}'");
	}
else {
	# Validate inputs
	&error_setup($text{'cpriv_err'});
	$in{'field'} || &error($text{'cpriv_efield'});
	$in{'user_def'} || $in{'user'} =~ /^\S+$/ ||
		&error($text{'cpriv_euser'});
	$in{'host_def'} || $in{'host'} =~ /^\S+$/ ||
		&error($text{'cpriv_ehost'});
	$in{'perms'} =~ s/\0/,/g;

	if ($in{'table'}) {
		# Create new column permissions
		($d, $t) = split(/\./, $in{'table'});
		$access{'perms'} == 1 || &can_edit_db($d) ||
			&error($text{'perms_edb'});
		$sql = "insert into columns_priv (host, db, user, ".
		       "table_name, column_name, column_priv) ".
		       "values (?, ?, ?, ?, ?, ?)";
		&execute_sql_logged($master_db, $sql,
			$in{'host_def'} ? '%' : $in{'host'},
			$d,
			$in{'user_def'} ? '' : $in{'user'},
			$t, $in{'field'}, $in{'perms'});
		}
	else {
		# Update existing column permissions
		$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
			&error($text{'perms_edb'});
		$sql = "update columns_priv set host = ?, user = ?, ".
		       "column_name = ?, column_priv = ? where host = ? ".
		       "and db = ? and user = ? and table_name = ? and ".
		       "column_name = ?";
		&execute_sql_logged($master_db, $sql,
			$in{'host_def'} ? '%' : $in{'host'},
			$in{'user_def'} ? '' : $in{'user'},
			$in{'field'}, $in{'perms'},
			$in{'oldhost'}, $in{'olddb'},
			$in{'olduser'}, $in{'oldtable'},
			$in{'oldfield'});
		}
	}
&execute_sql_logged($master_db, 'flush privileges');
if ($in{'delete'}) {
	&webmin_log("delete", "cpriv", $in{'oldtable'},
		    { 'user' => $in{'olduser'}, 'host' => $in{'oldhost'},
		      'db' => $in{'olddb'}, 'table' => $in{'oldtable'},
		      'field' => $in{'oldfield'} } );
	}
elsif ($in{'table'}) {
	&webmin_log("create", "cpriv", $in{'table'},
		    { 'user' => $in{'user_def'} ? '' : $in{'user'},
		      'host' => $in{'host_def'} ? '%' : $in{'host'},
		      'db' => $d, 'table' => $t, 'field' => $in{'field'} } );
	}
else {
	&webmin_log("modify", "cpriv", $in{'table'},
		    { 'user' => $in{'user_def'} ? '' : $in{'user'},
		      'host' => $in{'host_def'} ? '%' : $in{'host'},
		      'db' => $in{'olddb'}, 'table' => $in{'oldtable'},
		      'field' => $in{'field'} } );
	}
&redirect("list_cprivs.cgi");

