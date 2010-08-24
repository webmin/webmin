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

	map { $perms[$_]++ } split(/\0/, $in{'perms'});
	@desc = &table_structure($master_db, 'host');
	if ($in{'new'}) {
		# Create a new host
		for($i=2; $i<=&host_priv_cols()+2-1; $i++) {
			push(@yesno, $perms[$i] ? "'Y'" : "'N'");
			}
		$sql = sprintf "insert into host (%s) values ('%s', '%s', %s)",
			join(",", map { $desc[$_]->{'field'} } (0 .. &host_priv_cols()+2-1)),
			$in{'host_def'} ? '%' : $in{'host'}, $db,
			join(",", @yesno);
		}
	else {
		# Update existing host
		for($i=2; $i<=&host_priv_cols()+2-1; $i++) {
			push(@yesno, $desc[$i]->{'field'}."=".
				     ($perms[$i] ? "'Y'" : "'N'"));
			}
		$sql = sprintf "update host set host = '%s', db = '%s', %s ".
			       "where host = '%s' and db = '%s'",
			$in{'host_def'} ? '%' : $in{'host'}, $db,
			join(" , ", @yesno), $in{'oldhost'}, $in{'olddb'};
		}
	&execute_sql_logged($master_db, $sql);
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

