#!/usr/local/bin/perl
# edit_anon.cgi
# Display a form for editing some kind of anonymous option

require './proftpd-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
$anon = &find_directive_struct("Anonymous", $vconf);
$conf = $anon->{'members'};
@dirs = &editable_directives($in{'type'}, 'anon');
$desc = $in{'virt'} eq '' ? $text{'anon_header4'} :
	      &text('anon_header3', $v->{'value'});
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_anon.cgi", "post");
print &ui_hidden("type", $in{'type'});
print &ui_hidden("virt", $in{'virt'});
print &ui_table_start(&text('virt_header3', $text{"type_$in{'type'}"}),
		      "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
	"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

