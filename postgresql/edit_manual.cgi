#!/usr/local/bin/perl
# Show a config file for manual editing

require './postgresql-lib.pl';
$access{'users'} || &error($text{'host_ecannot'});
&ui_print_header(undef, $text{'manual_title'}, "");

# Config editor
print &ui_form_start("save_manual.cgi", "form-data");
print $form_hiddens;
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("data", &read_file_contents($hba_conf_file), 20, 80), 2);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
