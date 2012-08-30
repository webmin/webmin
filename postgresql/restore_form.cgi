#!/usr/local/bin/perl
# restore_form.cgi
# Display a form for restore a database

require './postgresql-lib.pl' ;

&ReadParse ( ) ;

&error_setup ( $text{'restore_err'} ) ;
$access{'restore'} || &error($text{'restore_ecannot'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&has_command($config{'rstr_cmd'}) ||
	&error(&text('restore_ecmd', "<tt>$config{'rstr_cmd'}</tt>"));

$desc = "<tt>$in{'db'}</tt>";
&ui_print_header($desc, $text{'restore_title'}, "", "restore_form" ) ;

print &ui_form_start("restore.cgi", "form-data");
print &ui_hidden("db", $in{'db'}),"\n";
print &ui_table_start($text{'restore_header'}, undef, 2);

print &ui_table_row($text{'restore_src'},
	&ui_radio("src", 0,
		[ [ 0, &text('restore_src0',
			     &ui_textbox("path", $config{'repository'}, 50).
			     &file_chooser_button("path")).
		       "<br>" ],
		  [ 1, &text('restore_src1',
			     &ui_upload("data")) ] ]));

print &ui_table_row($text{'restore_only'},
		    &ui_yesno_radio("only", 0));

print &ui_table_row($text{'restore_clean'},
		    &ui_yesno_radio("clean", 0));

print &ui_table_row($text{'restore_tables'},
		    &ui_opt_textbox("tables", undef, 60,
				    $text{'restore_tables1'}."<br>",
				    $text{'restore_tables0'}));

print &ui_table_end();
print &ui_form_end([ [ "go", $text{'restore_go'} ] ]);

&ui_print_footer("edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
	&get_databases_return_link($in{'db'}), $text{'index_return'});
