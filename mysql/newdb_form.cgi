#!/usr/local/bin/perl
# newdb_form.cgi
# Display a form for creating a new database

require './mysql-lib.pl';
$access{'create'} || &error($text{'newdb_ecannot'});
&ui_print_header(undef, $text{'newdb_title'}, "", "newdb_form");

print "<form action=newdb.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'newdb_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# DB name
print "<tr> <td><b>$text{'newdb_db'}</b></td>\n";
print "<td><input name=db size=15></td> </tr>\n";

if ($mysql_version >= 4.1) {
	# Character set option
	print "<tr> <td><b>$text{'newdb_charset'}</b></td>\n";
	print "<td>",&ui_select("charset", undef,
				[ [ undef, "&lt;$text{'default'}&gt;" ],
				  &list_character_sets() ]),"</td> </tr>\n";
	}

# Initial table name
print "<tr> <td><b>$text{'newdb_table'}</b></td> <td>\n";
print "<input name=table_def type=radio value=1 checked> $text{'newdb_none'}\n";
print "<input name=table_def type=radio value=0> $text{'newdb_tname'}\n";
print "<input name=table size=20> $text{'newdb_str'}</td> </tr>\n";

print "<tr> <td colspan=2>";
&show_table_form(4);
print "</td> </tr>\n";

print "<tr> <td colspan=2 align=right><input type=submit ",
      "value='$text{'create'}'></td> </tr>\n";

print "</table></td></tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

