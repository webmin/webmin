#!/usr/local/bin/perl
# save_grant.cgi
# Update privilege grants on some table/view/index

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'grant_ecannot'});

# Remove old privileges on object
if (&supports_schemas($in{'db'})) {
	$s = &execute_sql($in{'db'}, 'select relname, relacl, nspname from pg_class, pg_namespace where relnamespace = pg_namespace.oid and (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
	$ss = 1;
	}
else {
	$s = &execute_sql($in{'db'}, 'select relname, relacl, \'public\' from pg_class where (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
	$ss = 0;
	}
foreach $g (@{$s->{'data'}}) {
	if ($g->[0] eq $in{'table'} &&
	    $g->[2] eq $in{'ns'}) {
		@grant = &extract_grants($g->[1]);
		last;
		}
	}
$qt = $ss ? &quote_table($in{'ns'}.".".$in{'table'})
	  : &quote_table($in{'table'});
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
	&execute_sql_logged($in{'db'}, "revoke all on $qt from $who");
	}

# Grant new privileges
for($i=0; defined($in{"user_$i"}); $i++) {
	@what = split(/\0/, $in{"what_$i"});
	next if (!$in{"user_$i"} || !@what);
	if ($in{"user_$i"} eq "public") {
		$who = "public";
		}
	elsif ($in{"user_$i"} =~ /^group\s+(\S+)$/) {
		$who = "group \"$1\"";
		}
	else {
		$who = "\"".$in{"user_$i"}."\"";
		}
	&execute_sql_logged($in{'db'}, "grant ".join(",", @what)." on ".
				       "$qt to $who");
	}

&webmin_log("grant", undef, $in{'table'}, \%in);
&redirect("list_grants.cgi?search=".&urlize($in{'search'}));

