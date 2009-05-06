#!/usr/local/bin/perl
# Show a schema file for editing

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'schema'} || &error($text{'schema_ecannot'});
&ReadParse();
&is_under_directory($config{'schema_dir'}, $in{'file'}) ||
	&error($text{'schema_edir'});

&ui_print_header(undef, $text{'schema_etitle'}, "");

print $text{'schema_edesc'},"<p>\n";

print &ui_form_start("save_sfile.cgi", "form-data");
print &ui_hidden("file", $in{'file'});
print &ui_table_start($text{'schema_eheader'}, "width=100%", 2);

# Filename
print &ui_table_row($text{'schema_path'},
	"<tt>".&html_escape($in{'file'})."</tt>");

# Contents
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($in{'file'}), 20, 80,
		     undef, 0, "style='width:100%'"), 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_schema.cgi", $text{'schema_return'});

