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
		$in{'oldname'} =~ /^[A-Za-z0-9_]+$/ || &error($text{'group_ename'});
		&execute_sql_logged($config{'basedb'},
				    "drop group ".&pg_quote_ident($in{'oldname'}));
		}
	else {
		$in{'gid'} =~ /^\d+$/ || &error($text{'group_egid'});
		&execute_sql_logged($config{'basedb'},
				    "delete from pg_group where grosysid = ?",
				    $in{'gid'});
		}
	&webmin_log("delete", "group", $in{'name'});
	}
else {
	# parse inputs
	$in{'name'} =~ /^[A-Za-z0-9_]+$/ || &error($text{'group_ename'});
	$s = &execute_sql($config{'basedb'},
			  "select * from pg_group where groname = ?",
			  $in{'name'});
	$in{'gid'} =~ /^\d+$/ || &error($text{'group_egid'});
	if (!$in{'new'}) {
		$in{'oldname'} =~ /^[A-Za-z0-9_]+$/ || &error($text{'group_ename'});
		}
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
		foreach my $m (@mems) {
			defined($umap{$m}) ||
				&error("Invalid group member selected");
			}
		if ($in{'new'}) {
			$first = shift(@mems);
			my $csql = "create group ".&pg_quote_ident($in{'name'}).
				   " sysid $in{'gid'}";
			$csql .= " user ".&pg_quote_ident($umap{$first})
				if (defined($first));
			&execute_sql_logged($config{'basedb'}, $csql);
			if (@mems) {
				&execute_sql_logged($config{'basedb'},
					"alter group ".&pg_quote_ident($in{'name'}).
					" add user ".
					join(" , ", map { &pg_quote_ident($umap{$_}) } @mems));
				}
			}
		else {
			if ($in{'name'} ne $in{'oldname'}) {
				# Rename first
				&execute_sql_logged($config{'basedb'},
					"alter group ".&pg_quote_ident($in{'oldname'}).
					" rename to ".&pg_quote_ident($in{'name'}));
				}
			$s = &execute_sql($config{'basedb'},
					  "select * from pg_group where groname = ?",
					  $in{'name'});
			@oldmems = &split_array($s->{'data'}->[0]->[2]);
			my @dropmems = grep { defined($_) && $_ ne '' }
				       map { $umap{$_} } @oldmems;
			if (@oldmems && $oldmems[0] ne '') {
				&execute_sql_logged($config{'basedb'},
					"alter group ".&pg_quote_ident($in{'name'}).
					" drop user ".
					join(", ", map { &pg_quote_ident($_) } @dropmems))
					if (@dropmems);
				}
			if (@mems) {
				&execute_sql_logged($config{'basedb'},
					"alter group ".&pg_quote_ident($in{'name'}).
					" add user ".
					join(" , ", map { &pg_quote_ident($umap{$_}) } @mems));
				}
			}
		}
	else {
		# Can update group table directly
		$mems = &join_array(split(/\0/, $in{'mems'}));
		if ($in{'new'}) {
			&execute_sql_logged($config{'basedb'},
					    "insert into pg_group values (?, ?, ?)",
					    $in{'name'}, $in{'gid'}, $mems);
			}
		else {
			&execute_sql_logged($config{'basedb'},
					    "update pg_group set groname = ?, ".
					    "grolist = ? where grosysid = ?",
					    $in{'name'}, $mems, $in{'gid'});
			}
		}
	&webmin_log($in{'new'} ? "create" : "modify", "group", $in{'name'});
	}
&redirect("list_groups.cgi");

