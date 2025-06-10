#!/usr/local/bin/perl
# edit_popts.cgi
# Edit print-share specific options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvpopt'}")
        unless &can('ro', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'print_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'print_title2'}, "");
	}
&get_share($s);

print &ui_form_start("save_popts.cgi", "post");
print &ui_hidden("old_name", $s);
print &ui_table_start($text{'print_option'}, undef, 2);

print &ui_table_row($text{'print_minspace'},
	&ui_textbox("min_print_space", &getval("min print space"), 6)." kB");

print &ui_table_row($text{'print_postscript'},
	&yesno_input("postscript"));

print &ui_table_row($text{'print_command'},
	&ui_opt_textbox("print_command", &getval("print command"), 40,
			$text{'default'}));

print &ui_table_row($text{'print_queue'},
	&ui_opt_textbox("lpq_command", &getval("lpq command"), 40,
			$text{'default'}));

print &ui_table_row($text{'print_delete'},
	&ui_opt_textbox("lprm_command", &getval("lprm command"), 40,
			$text{'default'}));

print &ui_table_row($text{'print_pause'},
	&ui_opt_textbox("lppause_command", &getval("lppause command"), 40,
			$text{'default'}));

print &ui_table_row($text{'print_unresume'},
	&ui_opt_textbox("lpresume_command", &getval("lpresume command"), 40,
			$text{'default'}));

print &ui_table_row($text{'print_driver'},
	&ui_opt_textbox("printer_driver", &getval("printer driver"), 40,
			$text{'config_none'}));

print &ui_table_end();
if (&can('wO', \%access, $in{'share'})) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

&ui_print_footer("edit_pshare.cgi?share=".&urlize($s), $text{'index_printershare'},
	"", $text{'index_sharelist'});

