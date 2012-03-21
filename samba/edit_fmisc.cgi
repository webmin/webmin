#!/usr/local/bin/perl
# edit_fmisc.cgi
# Edit misc file options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvfmisc'}")
		unless &can('ro', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fmisc_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'fmisc_title'}, "");
	print "<center><font size=+1>", &text('fmisc_for', $s),"</font></center>\n";
	}
&get_share($s);

print &ui_form_start("save_fmisc.cgi", "post");
print &ui_hidden("old_name", $s);
print &ui_table_start($text{'misc_title'}, undef, 2);

print &ui_table_row($text{'fmisc_lockfile'},
	&yesno_input("locking"));

$max = &getval("max connections");
print &ui_table_row($text{'fmisc_maxconn'},
	&ui_opt_textbox("max_connections", $max == 0 ? undef : $max, 6,
		        $text{'smb_unlimited'}));

print &ui_table_row($text{'fmisc_oplocks'},
	&yesno_input("oplocks"));

print &ui_table_row($text{'fmisc_level2'},
	&yesno_input("level2 oplocks"));

print &ui_table_row($text{'fmisc_fake'},
	&yesno_input("fake oplocks"));

print &ui_table_row($text{'fmisc_sharemode'},
	&yesno_input("share modes"));

print &ui_table_row($text{'fmisc_strict'},
	&yesno_input("strict locking"));

print &ui_table_row($text{'fmisc_sync'},
	&yesno_input("sync always"));

print &ui_table_row($text{'fmisc_volume'},
	&ui_opt_textbox("volume", &getval("volume"), 25,
			$text{'fmisc_sameas'}));

print &ui_table_row($text{'fmisc_unixdos'},
	&ui_textbox("mangled_map", &getval("mangled map"), 40));

print &ui_table_row($text{'fmisc_conncmd'},
	&ui_textbox("preexec", &getval("preexec"), 40));

print &ui_table_row($text{'fmisc_disconncmd'},
	&ui_textbox("postexec", &getval("postexec"), 40));

print &ui_table_row($text{'fmisc_rootconn'},
	&ui_textbox("root_preexec", &getval("root preexec"), 40));

print &ui_table_row($text{'fmisc_rootdisconn'},
	&ui_textbox("root_postexec", &getval("root postexec"), 40));

print &ui_table_end();
if (&can('wO', \%access, $in{'share'})) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

