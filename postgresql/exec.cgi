#!/usr/local/bin/perl
# exec.cgi
# Execute some SQL command and display output

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&error_setup($text{'exec_err'});
$d = &execute_sql_logged($in{'db'}, $in{'cmd'});

&ui_print_header(undef, $text{'exec_title'}, "");
print &text('exec_out', "<tt>$in{'cmd'}</tt>"),"<p>\n";
@data = @{$d->{'data'}};
if (@data) {
	print &ui_columns_start($d->{'titles'});
	foreach $r (@data) {
		print &ui_columns_row($r);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'exec_none'}</b> <p>\n";
	}
&webmin_log("exec", undef, $in{'db'}, \%in);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});

