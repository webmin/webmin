#!/usr/local/bin/perl
# edit_ftpaccess.cgi
# Display a form for editing some kind of per-directory options file

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_ftpaccess_config($in{'file'});
@dirs = &editable_directives($in{'type'}, 'ftpaccess');
$desc = &text('ftpindex_header', "<tt>".&html_escape($in{'file'})."</tt>");
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_ftpaccess.cgi", "post");
print &ui_hidden("type", $in{'type'});
print &ui_hidden("file", $in{'file'});
print &ui_table_start(&text('ftpindex_header2', $text{"type_$in{'type'}"},
                            "<tt>".&html_escape($in{'file'})."</tt>"),
		      "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("ftpaccess_index.cgi?file=$in{'file'}", $text{'ftpindex_return'},
	"ftpaccess.cgi", $text{'ftpaccess_return'},
	"", $text{'index_return'});


