#!/usr/local/bin/perl
# conf_print.cgi
# Display printing options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcprint'}") unless $access{'conf_print'};
 
&ui_print_header(undef, $text{'print_title'}, "");

&get_share("global");

print &ui_form_start("save_print.cgi", "post");
print &ui_table_start($text{'print_title'}, undef, 2);

print &ui_table_row($text{'print_style'},
	&ui_select("printing", &getval("printing"),
		   [ [ "", $text{'default'} ],
		     "bsd", "sysv", "hpux", "aix", "qnx", "plp", "cups",
		     "lprng", "softq" ], 1, 0, 1));

print &ui_table_row($text{'print_show'},
	&yesno_input("load printers"));

print &ui_table_row($text{'print_printcap'},
	&ui_opt_textbox("printcap_name", &getval("printcap name"), 40,
			$text{'default'})." ".
	&file_chooser_button("printcap_name", 0));

$ct = &getval("lpq cache time");
print &ui_table_row($text{'print_cachetime'},
	&ui_opt_textbox("lpq_cache_time", $ct == 0 ? undef : $ct, 5,
			$text{'default'})." ".$text{'config_secs'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});
