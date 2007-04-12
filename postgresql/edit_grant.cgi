#!/usr/local/bin/perl
# edit_grant.cgi
# Display a form for editing or creating a grant

require './postgresql-lib.pl';
&ReadParse();
$access{'users'} || &error($text{'grant_ecannot'});
&ui_print_header(undef, $text{'grant_edit'}, "");
if (&supports_schemas($in{'db'})) {
	$s = &execute_sql_safe($in{'db'}, 'select relname, relacl, nspname from pg_class, pg_namespace where relnamespace = pg_namespace.oid and (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
	}
else {
	$s = &execute_sql_safe($in{'db'}, 'select relname, relacl, \'public\' from pg_class where (relkind = \'r\' OR relkind = \'S\') and relname !~ \'^pg_\' order by relname');
	}
foreach $g (@{$s->{'data'}}) {
	if ($g->[0] eq $in{'table'} &&
	    $g->[2] eq $in{'ns'}) {
		$g->[1] =~ s/^\{//; $g->[1] =~ s/\}$//;
		@grant = map { /^"(.*)=(.*)"$/ || /^(.*)=(.*)$/; [ $1, $2 ] }
			     split(/,/, $g->[1]);
		}
	}

print "<form action=save_grant.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=ns value='$in{'ns'}'>\n";
print "<input type=hidden name=type value='$in{'type'}'>\n";
print "<input type=hidden name=search value='$in{'search'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'grant_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'grant_db'}</b></td>\n";
print "<td><tt>$in{'db'}</tt></td> <td colspan=2 width=50%></td> </tr>\n";

print "<tr> <td><b>$text{'grant_ns'}</b></td>\n";
print "<td><tt>$in{'ns'}</tt></td> <td colspan=2 width=50%></td> </tr>\n";

print "<tr> <td><b>",$text{"grant_$in{'type'}"},"</b></td>\n";
print "<td><tt>$in{'table'}</tt></td> <td colspan=2 width=50%></td> </tr>\n";

$u = &execute_sql_safe($config{'basedb'}, "select usename from pg_shadow");
@users = map { $_->[0] } @{$u->{'data'}};

$r = &execute_sql_safe($config{'basedb'}, "select groname from pg_group");
@groups = map { $_->[0] } @{$r->{'data'}};

print "<tr> <td colspan=4><b>$text{'grant_users'}</b><br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'grant_user'}</b></td> ",
      "<td><b>$text{'grant_what'}</b></td> </tr>\n";
$i = 0;
foreach $g (@grant, [ undef, undef ]) {
	print "<tr> <td><select name=user_$i>\n";
	printf "<option %s value=''>&nbsp;\n",
		defined($g->[0]) ? "" : "selected";
	printf "<option value=public %s>%s\n",
		defined($g->[0]) && $g->[0] eq '' ? 'selected' : '',
		$text{'grant_public'};
	foreach $r (@groups) {
		printf "<option value='%s' %s>%s\n",
			"group $r", $g->[0] eq "group $r" ? 'selected' : '',
			&text('grant_group', $r);
		}
	foreach $u (@users) {
		printf "<option %s>%s\n",
			$g->[0] eq $u ? 'selected' : '', $u;
		}
	print "</select></td> <td>\n";

	($acl = $g->[1]) =~ s/\/.*//g;
	foreach $p ( [ 'SELECT', 'r' ], [ 'UPDATE', 'w' ],
		     [ 'INSERT', 'a' ], [ 'DELETE', 'd' ],
		     [ 'RULE', 'R' ], [ 'REFERENCES', 'x' ],
		     [ 'TRIGGER', 't' ] ) {
		printf "<input type=checkbox name=what_$i value=%s %s> %s\n",
			$p->[0], $acl =~ /$p->[1]/ ? 'checked' : '', $p->[0];
		}
	print "</td> </tr>\n";
	$i++;
	}
print "</table></td></tr>\n";
print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("list_grants.cgi?search=".&urlize($in{'search'}),
		 $text{'grant_return'});

