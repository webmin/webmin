#!/usr/local/bin/perl
# Reset privilege grants on some table/view/index

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'dgrant_err'});
$access{'users'} || &error($text{'grant_ecannot'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'dgrant_enone'});

foreach $d (@d) {
	($db, $table, $ns, $type) = split(/\//, $d, -1);
	$ss = &supports_schemas($db);

	# Get old privileges
	if ($ss) {
		$s = &execute_sql($db, 'select relname, relacl, nspname from pg_class, pg_namespace where relnamespace = pg_namespace.oid and (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
		$ss = 1;
		}
	else {
		$s = &execute_sql($db, 'select relname, relacl, \'public\' from pg_class where (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
		$ss = 0;
		}
	foreach $g (@{$s->{'data'}}) {
		if ($g->[0] eq $table &&
		    $g->[2] eq $ns) {
			$g->[1] =~ s/^\{//; $g->[1] =~ s/\}$//;
			@grant = map { /^"(.*)=(.*)"$/ || /^(.*)=(.*)$/; [ $1, $2 ] }
				     split(/,/, $g->[1]);
			}
		}

	# Revoke them
	$qt = $ss ? &quote_table($ns.".".$table)
		  : &quote_table($table);
	foreach $g (@grant) {
		next if (!$g->[1]);
		if ($g->[0] eq '') {
			$who = "public";
			}
		elsif ($g->[0] =~ /group\s+(\S+)/) {
			$who = "group \"$1\"";
			}
		else {
			$who = "\"$g->[0]\"";
			}
		&execute_sql_logged($db, "revoke all on $qt from $who");
		}
	}

&webmin_log("degrant", undef, scalar(@d));
&redirect("list_grants.cgi?search=".&urlize($in{'search'}));

