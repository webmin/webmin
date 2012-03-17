#!/usr/local/bin/perl
# edit_fperm.cgi
# Edit file permissions options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvperm'}")
        unless &can('rp', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fperm_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'fperm_title2'}, "");
	print "<center><font size=+1>", &text('fmisc_for', $s), "</font></center>\n";
	}
&get_share($s);

print &ui_form_start("save_fperm.cgi", "post");
print &ui_hidden("old_name", $s);
print &ui_table_start($text{'fperm_option'}, undef, 2);

print &ui_table_row($text{'fperm_filemode'},
	&ui_textbox("create_mode", &getval("create mode"), 5));

print &ui_table_row($text{'fperm_dirmode'},
	&ui_textbox("directory_mode", &getval("directory mode"), 5));

print &ui_table_row($text{'fperm_notlist'},
	&ui_textbox("dont_descend", &getval("dont descend"), 40));

print &ui_table_row($text{'fperm_forceuser'},
	&username_input("force user", "None"));

print &ui_table_row($text{'fperm_forcegrp'},
	&groupname_input("force group", "None"));

print &ui_table_row($text{'fperm_link'},
	&yesno_input("wide links"));

print &ui_table_row($text{'fperm_delro'},
	&yesno_input("delete readonly"));

print &ui_table_row($text{'fperm_forcefile'},
	&ui_textbox("force_create_mode", &getval("force create mode"), 5));

print &ui_table_row($text{'fperm_forcedir'},
	&ui_textbox("force_directory_mode", &getval("force directory mode"),5));

print &ui_table_end();
if (&can('wP', \%access, $in{'share'})) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

