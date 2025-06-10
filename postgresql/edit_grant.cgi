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
		@grant = &extract_grants($g->[1]);
		last;
		}
	}

# Start of form block
print &ui_form_start("save_grant.cgi", "post");
print &ui_hidden("db", $in{'db'});
print &ui_hidden("table", $in{'table'});
print &ui_hidden("ns", $in{'ns'});
print &ui_hidden("type", $in{'type'});
print &ui_hidden("search", $in{'search'});
print &ui_table_start($text{'grant_header'}, undef, 2);

# Database name
print &ui_table_row($text{'grant_db'}, "<tt>$in{'db'}</tt>");

# Schema name
print &ui_table_row($text{'grant_ns'}, "<tt>$in{'ns'}</tt>");

# Object name
print &ui_table_row($text{"grant_$in{'type'}"}, "<tt>$in{'table'}</tt>");

# Get users and groups for permissions table
($st) = &get_pg_shadow_table();
$u = &execute_sql_safe($config{'basedb'}, "select usename from $st");
@users = map { $_->[0] } @{$u->{'data'}};

$r = &execute_sql_safe($config{'basedb'}, "select groname from pg_group");
@groups = map { $_->[0] } @{$r->{'data'}};

# Table of users / groups and permissions
$i = 0;
@table = ( );
foreach $g (@grant, [ undef, undef ]) {
	# User / group selector
	local @row;
	push(@row, &ui_select("user_$i", 
			!defined($g->[0]) ? "" :
			$g->[0] eq '' ? "public" : $g->[0],
			[ [ '', '&nbsp;' ],
			  [ 'public', $text{'grant_public'} ],
			  (map { [ "group $_", &text('grant_group', $_) ] }
			       @groups),
			  (@users) ], 1, 0, 1));

	# Permissions
	($acl = $g->[1]) =~ s/\/.*//g;
	$cbs = "";
	foreach $p ( [ 'SELECT', 'r' ], [ 'UPDATE', 'w' ],
		     [ 'INSERT', 'a' ], [ 'DELETE', 'd' ],
		     [ 'RULE', 'R' ], [ 'REFERENCES', 'x' ],
		     [ 'TRIGGER', 't' ] ) {
		$cbs .= &ui_checkbox("what_$i", $p->[0], $p->[0],
				     $acl =~ /$p->[1]/)."\n";
		}
	push(@row, $cbs);
	push(@table, \@row);
	$i++;
	}
print &ui_table_row($text{'grant_users'},
	&ui_columns_table([ $text{'grant_user'}, $text{'grant_what'} ],
			  undef,
			  \@table));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("list_grants.cgi?search=".&urlize($in{'search'}),
		 $text{'grant_return'});

