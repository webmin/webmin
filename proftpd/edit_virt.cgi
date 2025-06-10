#!/usr/local/bin/perl
# edit_virt.cgi
# Display a form for editing some kind of per-server options

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
@dirs = &editable_directives($in{'type'}, 'virtual');
$desc = $in{'virt'} eq '' ? $text{'virt_header2'} :
	      &text('virt_header1', $v->{'value'});
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_virt.cgi", "post");
print &ui_hidden("type", $in{'type'});
print &ui_hidden("virt", $in{'virt'});
print &ui_table_start(&text('virt_header3', $text{"type_$in{'type'}"}),
		      "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});


