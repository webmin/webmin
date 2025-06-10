#!/usr/local/bin/perl
# save_group.cgi
# Create, update or delete a postgres group

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'group_ecannot'});
&error_setup($text{'group_err'});

if ($in{'delete'}) {
	# just delete the group
	if (&get_postgresql_version() >= 8.0) {
		&execute_sql_logged($config{'basedb'}, "drop group $in{'oldname'}");
		}
	else {
		&execute_sql_logged($config{'basedb'}, "delete from pg_group where grosysid = $in{'gid'}");
		}
	&webmin_log("delete", "group", $in{'name'});
	}
else {
	# parse inputs
	$in{'name'} =~ /^\S+$/ || &error($text{'group_ename'});
	$s = &execute_sql($config{'basedb'}, "select * from pg_group where groname = '$in{'name'}'");
	$in{'gid'} =~ /^\d+$/ || &error($text{'group_egid'});
	if ($in{'new'}) {
		$s->{'data'}->[0]->[0] && &error($text{'group_etaken'});
		}
	else {
		$s->{'data'}->[0]->[0] && $s->{'data'}->[0]->[1] != $in{'gid'} && &error($text{'group_etaken'});
		}

	# Actually create or update the group
	if (&get_postgresql_version() >= 8.0) {
		# Need to use new create group or modify command
		($pg_table, $pg_cols) = &get_pg_shadow_table();
		$s = &execute_sql($config{'basedb'}, "select $pg_cols from $pg_table");
		foreach $u (@{$s->{'data'}}) {
			$umap{$u->[1]} = $u->[0];
			}
		@mems = split(/\r?\n/, $in{'mems'});
		if ($in{'new'}) {
			$first = shift(@mems);
			&execute_sql_logged($config{'basedb'}, "create group $in{'name'} sysid $in{'gid'} user ".$umap{$first});
			if (@mems) {
				&execute_sql_logged($config{'basedb'}, "alter group $in{'name'} add user ".join(" , ", map { $umap{$_} } @mems));
				}
			}
		else {
			if ($in{'name'} ne $in{'oldname'}) {
				# Rename first
				&execute_sql_logged($config{'basedb'}, "alter group $in{'oldname'} rename to $in{'name'}");
				}
			$s = &execute_sql($config{'basedb'}, "select * from pg_group where groname = '$in{'name'}'");
			@oldmems = &split_array($s->{'data'}->[0]->[2]);
			if (@oldmems && $oldmems[0] ne '') {
				&execute_sql_logged($config{'basedb'}, "alter group $in{'name'} drop user ".join(", ", map { $umap{$_} } @oldmems));
				}
			if (@mems) {
				&execute_sql_logged($config{'basedb'}, "alter group $in{'name'} add user ".join(" , ", map { $umap{$_} } @mems));
				}
			}
		}
	else {
		# Can update group table directly
		$mems = &join_array(split(/\0/, $in{'mems'}));
		if ($in{'new'}) {
			&execute_sql_logged($config{'basedb'}, "insert into pg_group values ('$in{'name'}', '$in{'gid'}', '$mems')");
			}
		else {
			&execute_sql_logged($config{'basedb'}, "update pg_group set groname = '$in{'name'}', grolist = '$mems' where grosysid = $in{'gid'}");
			}
		}
	&webmin_log($in{'new'} ? "create" : "modify", "group", $in{'name'});
	}
&redirect("list_groups.cgi");

