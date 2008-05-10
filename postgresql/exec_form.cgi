#!/usr/local/bin/perl
# exec_form.cgi
# Display a form for executing SQL in some database

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&ui_print_header(undef, $text{'exec_title'}, "", "exec_form");

# Form for executing an SQL command
print "<p>",&text('exec_header', "<tt>$in{'db'}</tt>"),"<p>\n";
print "<form action=exec.cgi method=post>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<textarea name=cmd rows=10 cols=70></textarea><br>\n";
print "<input type=submit value='$text{'exec_exec'}'></form>\n";

# Form for executing commands from a file
print &ui_hr();
print "<p>",&text('exec_header2', "<tt>$in{'db'}</tt>"),"<p>\n";
print "<form action=exec_file.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=db value='$in{'db'}'> <table>\n";
print "<tr> <td><input type=radio name=mode value=0 checked> ",
      "$text{'exec_file'}</td> <td><input name=file size=40> ",
      &file_chooser_button("file", 0, 1),"</td> </tr>\n";
print "<tr> <td><input type=radio name=mode value=1> ",
      "$text{'exec_upload'}</td> ",
      "<td><input name=upload type=file></td> </tr>\n";
print "</table> <input type=submit value='$text{'exec_exec'}'></form>\n";

# Form for loading a CSV or tab-separated file
print &ui_hr();
print "<p>",&text('exec_header3', "<tt>$in{'db'}</tt>"),"<br>",
      $text{'exec_header4'},"<p>\n";
print "<form action=import.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=db value='$in{'db'}'> <table>\n";

print "<tr> <td><input type=radio name=mode value=0 checked> ",
      "$text{'exec_file'}</td> <td><input name=file size=40> ",
      &file_chooser_button("file", 0, 2),"</td> </tr>\n";

print "<tr> <td><input type=radio name=mode value=1> ",
      "$text{'exec_upload'}</td> ",
      "<td><input name=upload type=file></td> </tr>\n";

print "<tr> <td><b>$text{'exec_import'}</b></td>\n";
print "<td><select name=table>\n";
foreach $t (&list_tables($in{'db'})) {
	print "<option>$t\n";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'exec_delete'}</b></td>\n";
print "<td><input type=radio name=delete value=1> $text{'yes'}\n";
print "<input type=radio name=delete value=0 checked> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'exec_ignore'}</b></td>\n";
print "<td><input type=radio name=ignore value=1> $text{'yes'}\n";
print "<input type=radio name=ignore value=0 checked> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'exec_format'}</b></td>\n";
print "<td>",&ui_radio("format", 2, [ [ 0, $text{'csv_format0'} ],
				      [ 1, $text{'csv_format1'} ],
				      [ 2, $text{'csv_format2'} ] ]),
      "</td> </tr>\n";

print "</table> <input type=submit value='$text{'exec_exec'}'></form>\n";



&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});
