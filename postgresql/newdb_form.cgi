#!/usr/local/bin/perl
# newdb_form.cgi
# Display a form for creating a new database

require './postgresql-lib.pl';
$access{'create'} || &error($text{'newdb_ecannot'});
&ui_print_header(undef, $text{'newdb_title'}, "", "newdb_form");

print "<form action=newdb.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'newdb_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Database name
print "<tr> <td><b>$text{'newdb_db'}</b></td>\n";
print "<td><input name=db size=15></td> </tr>\n";

if (&get_postgresql_version() >= 7) {
	# Owner option
	print "<tr> <td><b>$text{'newdb_user'}</b></td>\n";
	print "<td><input type=radio name=user_def value=1 checked> $text{'default'}\n";
	print "<input type=radio name=user_def value=0>\n";
	print "<select name=user>\n";
	$u = &execute_sql($config{'basedb'}, "select usename from pg_shadow");
	@users = map { $_->[0] } @{$u->{'data'}};
	foreach $u (@users) {
		print "<option>$u\n";
		}
	print "</select></td> </tr>\n";
	}

if (&get_postgresql_version() >= 8) {
	# Encoding option
	print "<tr> <td><b>$text{'newdb_encoding'}</b></td>\n";
	print "<td>",&ui_opt_textbox("encoding", undef, 20, $text{'default'}),
	      "</td> </tr>\n";
	}

# Path to database file
print "<tr> <td><b>$text{'newdb_path'}</b></td>\n";
print "<td>",&ui_opt_textbox("path", undef, 30, $text{'default'}),
      "</td> </tr>\n";

print "<tr> <td colspan=2 align=right><input type=submit ",
      "value='$text{'create'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

