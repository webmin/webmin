#!/usr/local/bin/perl
# save_host.cgi
# Save, create or delete a host table record

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});

if ($in{'delete'}) {
	# Delete some host
	$access{'perms'} == 1 || &can_edit_db($in{'olddb'}) ||
		&error($text{'perms_edb'});
	&execute_sql_logged($master_db,
		     "delete from host where host = '$in{'oldhost'}' ".
		     "and db = '$in{'olddb'}'");
	}
else {
	# Validate inputs
	&error_setup($text{'host_err'});
	$in{'host_def'} || $in{'host'} =~ /^\S+$/ ||
		&error($text{'host_ehost'});
	if ($access{'perms'} == 2 && $access{'dbs'} ne '*') {
		$db = $in{'dbs'};
		}
	else {
		$db = $in{'db_def'} == 1 ? "" :
		      $in{'db_def'} == 2 ? $in{'dbs'} : $in{'db'};
		$db =~ /^\S*$/ || &error($text{'host_edb'});
		}
	if ($access{'perms'} == 2) {
		$in{'new'} || &can_edit_db($in{'olddb'}) ||
			&error($text{'perms_edb'});
		&can_edit_db($db) || &error($text{'perms_edb'});
		}

        %perms = map { $_, 1 } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'host');
        @pfields = map { $_->[0] } &priv_fields('host');
	$host = $in{'host_def'} ? '%' : $in{'host'};
	if ($in{'new'}) {
		# Create a new host
		$sql = "insert into host (host, db, ".
                       join(", ", @pfields).
                       ") values (?, ?, ".
                       join(", ", map { "?" } @pfields).")";
                &execute_sql_logged($master_db, $sql,
                        $host, $db,
                        (map { $perms{$_} ? 'Y' : 'N' } @pfields));
		}
	else {
		# Update existing host
		$sql = "update host set host = ?, db = ?, ".
		       join(", ",map { "$_ = ?" } @pfields).
		       " where host = ? and db = ?";
		&execute_sql_logged($master_db, $sql,
			$host, $db,
			(map { $perms{$_} ? 'Y' : 'N' } @pfields),
			$in{'oldhost'}, $in{'olddb'});
		}
	}
&execute_sql_logged($master_db, 'flush privileges');
if ($in{'delete'}) {
	&webmin_log("delete", "host", $in{'oldhost'},
		    { 'db' => $in{'olddb'},
		      'host' => $in{'oldhost'} } );
	}
elsif ($in{'new'}) {
	&webmin_log("create", "host", $in{'host_def'} ? '' : $in{'host'},
		    { 'db' => $db,
		      'host' => $in{'host_def'} ? '' : $in{'host'} } );
	}
else {
	&webmin_log("modify", "host", $in{'host_def'} ? '' : $in{'host'},
		    { 'db' => $db,
		      'host' => $in{'host_def'} ? '' : $in{'host'} } );
	}
&redirect("list_hosts.cgi");

