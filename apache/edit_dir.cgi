#!/usr/local/bin/perl
# edit_dir.cgi
# Display a form for editing some kind of per-directory options

require './apache-lib.pl';
&ReadParse();
($vconf, $v) = &get_virtual_config($in{'virt'});
&can_edit_virt($v) || &error($text{'virt_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
$d = $vconf->[$in{'idx'}];
$conf = $d->{'members'};
@dirs = &editable_directives($in{'type'}, 'directory');
$desc = &text('dir_header', &dir_name($d), &virtual_name($v));
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_dir.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("type", $in{'type'});
print &ui_table_start(&text('dir_header2', $text{"type_$in{'type'}"},
                               &dir_name($d)), "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}", $text{'dir_return'});


