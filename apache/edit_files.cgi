#!/usr/local/bin/perl
# edit_virt.cgi
# Display a form for editing some kind of per-directory options file

require './apache-lib.pl';
&ReadParse();
$access{'global'} || &error($text{'htaccess_ecannot'});
$access_types{$in{'type'}} || &error($text{'etype'});
&allowed_auth_file($in{'file'}) || &error($text{'htindex_ecannot'});
$hconf = &get_htaccess_config($in{'file'});
$d = $hconf->[$in{'idx'}];
$conf = $d->{'members'};
@dirs = &editable_directives($in{'type'}, 'directory');
$desc = &text('htfile_header', &dir_name($d), "<tt>$in{'file'}</tt>");
&ui_print_header($desc, $text{"type_$in{'type'}"}, "");

print &ui_form_start("save_files.cgi", "post");
print &ui_hidden("file", $in{'file'});
print &ui_hidden("type", $in{'type'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start(&text('htfile_header2', $text{"type_$in{'type'}"},
                            &dir_name($d)), "width=100%", 4);
&generate_inputs(\@dirs, $conf);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("htaccess_index.cgi?file=$in{'file'}", $text{'htindex_return'});


