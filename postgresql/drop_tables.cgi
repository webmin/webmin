#!/usr/local/bin/perl
# Delete multiple tables

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@tables = split(/\0/, $in{'d'});
@tables || &error($text{'tdrops_enone'});

if ($in{'confirm'}) {
	# Drop the tables, views, sequences and indexes (tables last)
	&error_setup($text{'tdrops_err'});
	foreach $t (@tables) {
		if ($t =~ /^\!(.*)$/) {
			$qt = &quote_table($1);
			&execute_sql_logged($in{'db'}, "drop index $qt");
			}
		elsif ($t =~ /^\*(.*)$/) {
			$qt = &quote_table($1);
			&execute_sql_logged($in{'db'}, "drop view $qt");
			}
		elsif ($t =~ /^\/(.*)$/) {
			$qt = &quote_table($1);
			&execute_sql_logged($in{'db'}, "drop sequence $qt");
			}
		else {
			push(@rest, $t);
			}
		}
	foreach $t (@rest) {
		$qt = &quote_table($t);
		&execute_sql_logged($in{'db'}, "drop table $qt");
		}
	&webmin_log("delete", "tables", scalar(@tables), \%in);
	&redirect("edit_dbase.cgi?db=$in{'db'}");
	}
else {
	# Ask the user if he is sure..
	&ui_print_header(undef, $text{'tdrops_title'}, "");
	foreach $t (@tables) {
		if ($t !~ /^\!/ && $t !~ /^\*/ && $t !~ /^\//) {
			$qt = &quote_table($t);
			$d = &execute_sql_safe($in{'db'}, "select count(*) from $qt");
			$rows += $d->{'data'}->[0]->[0];
			}
		}

	$msg = defined($rows) ? 'tdrops_rusure' : 'tdrops_rusure2';
	print "<center><b>", &text($msg, scalar(@tables),
				   "<tt>$in{'db'}</tt>", $rows),"</b><p>\n";
	print "<form action=drop_tables.cgi>\n";
	print "<input type=hidden name=db value='$in{'db'}'>\n";
	foreach $t (@tables) {
		print &ui_hidden("d", $t),"\n";
		}
	print "<input type=submit name=confirm value='$text{'tdrops_ok'}'>\n";
	print "</form></center>\n";
	&ui_print_footer("edit_dbase.cgi?db=$in{'db'}",
			$text{'dbase_return'});
	}

