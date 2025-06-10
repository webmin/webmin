#!/usr/local/bin/perl
# Drop multiple tables, views and indexes, after asking for confirmation

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
@tables = split(/\0/, $in{'d'});
@tables || &error($text{'tdrops_enone'});

if ($in{'confirm'}) {
	# Drop the tables, views and indexes (tables last)
	&error_setup($text{'tdrops_err'});
	foreach $t (@tables) {
		if ($t =~ /^\!(.*)$/) {
			$str = &index_structure($in{'db'}, $1);
			&execute_sql_logged($in{'db'}, "drop index ".&quotestr($1)." on ".quotestr($str->{'table'}));
			}
		elsif ($t =~ /^\*(.*)$/) {
			&execute_sql_logged($in{'db'}, "drop view ".&quotestr($1));
			}
		else {
			push(@rest, $t);
			}
		}
	foreach $t (@rest) {
		&execute_sql_logged($in{'db'}, "drop table ".&quotestr($t));
		}
	&webmin_log("delete", "tables", scalar(@tables), \%in);
	&redirect("edit_dbase.cgi?db=$in{'db'}");
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'tdrops_title'}, "");
	foreach $t (@tables) {
		if ($t !~ /^\!/ && $t !~ /^\*/) {
			$d = &execute_sql($in{'db'},
				"select count(*) from ".&quotestr($t));
			$rows += $d->{'data'}->[0]->[0];
			}
		}

	$msg = defined($rows) ? 'tdrops_rusure' : 'tdrops_rusure2';
	print "<center><b>", &text($msg, scalar(@tables),
				   "<tt>$in{'db'}</tt>", $rows),"</b><p>\n";
	print "<form action=drop_tables.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	print "<input type=submit name=confirm value='$text{'tdrops_ok'}'>\n";
	foreach $t (@tables) {
		print &ui_hidden("d", $t),"\n";
		}
	print "</form></center>\n";
	&ui_print_footer(
		"edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}

