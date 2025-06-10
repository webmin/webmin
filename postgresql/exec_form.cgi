#!/usr/local/bin/perl
# exec_form.cgi
# Display a form for executing SQL in some database

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&ui_print_header(undef, $text{'exec_title'}, "", "exec_form");

# Generate tabs for sections
$prog = "exec_form.cgi?db=".&urlize($in{'db'})."&mode=";
@tabs = ( [ "exec", $text{'exec_tabexec'}, $prog."exec" ],
	  [ "file", $text{'exec_tabfile'}, $prog."file" ],
	  [ "import", $text{'exec_tabimport'}, $prog."import" ] );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "exec", 1);

# Get recently run commands
open(OLD, "<$commands_file.$in{'db'}");
while(<OLD>) {
	s/\r|\n//g;
	push(@old, $_);
	}
close(OLD);

# Form for executing an SQL command
print &ui_tabs_start_tab("mode", "exec");
print &text('exec_header', "<tt>$in{'db'}</tt>"),"<p>\n";
print &ui_form_start("exec.cgi", "form-data");
print &ui_hidden("db", $in{'db'});
print &ui_textarea("cmd", undef, 10, 70),"<br>\n";
if (@old) {
	print $text{'exec_old'}," ",
	      &ui_select("old", undef,
		[ map { [ $_, &html_escape(length($_) > 80 ?
				substr($_, 0, 80).".." : $_) ] } @old ]),"\n",
	      &ui_button($text{'exec_edit'}, "movecmd", undef,
		"onClick='cmd.value = old.options[old.selectedIndex].value'"),
	      " ",&ui_submit($text{'exec_clear'}, "clear"),"<br>\n";
	}
print &ui_form_end([ [ undef, $text{'exec_exec'} ] ]);
print &ui_tabs_end_tab();

# Form for executing commands from a file
print &ui_tabs_start_tab("mode", "file");
print &text('exec_header2', "<tt>$in{'db'}</tt>"),"<p>\n";
print &ui_form_start("exec_file.cgi", "form-data");
print &ui_hidden("db", $in{'db'});
print &ui_radio_table("mode", 0, [
	[ 0, $text{'exec_file'}, &ui_textbox("file", undef, 50)." ".
				 &file_chooser_button("file", 0, 1) ],
	[ 1, $text{'exec_upload'}, &ui_upload("upload", 50) ] ]);
print &ui_form_end([ [ undef, $text{'exec_exec'} ] ]);
print &ui_tabs_end_tab();

# Form for loading a CSV or tab-separated file
print &ui_tabs_start_tab("mode", "import");
print &text('exec_header3', "<tt>$in{'db'}</tt>"),"<br>",
      $text{'exec_header4'},"<p>\n";
print &ui_form_start("import.cgi", "form-data");
print &ui_hidden("db", $in{'db'});
print &ui_table_start(undef, undef, 2);

# Source for CSV file
print &ui_table_row($text{'exec_importmode'},
	&ui_radio_table("mode", 0, [
		[ 0, $text{'exec_file'}, &ui_textbox("file", undef, 50)." ".
					 &file_chooser_button("file", 0, 1) ],
		[ 1, $text{'exec_upload'}, &ui_upload("upload", 50) ] ]));

# Table to import into
print &ui_table_row($text{'exec_import'},
	&ui_select("table", undef, [ &list_tables($in{'db'}) ]));

# Delete existing rows?
print &ui_table_row($text{'exec_delete'},
	&ui_yesno_radio("delete", 0));

# Ignore dupes?
print &ui_table_row($text{'exec_ignore'},
	&ui_yesno_radio("ignore", 0));

# CSV format
print &ui_table_row($text{'exec_format'},
	&ui_radio("format", 2, [ [ 0, $text{'csv_format0'} ],
				 [ 1, $text{'csv_format1'} ],
				 [ 2, $text{'csv_format2'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'exec_exec'} ] ]);

print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	"", $text{'index_return'});
