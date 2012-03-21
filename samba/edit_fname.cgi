#!/usr/local/bin/perl
# edit_fname.cgi
# Edit file naming options

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvfname'}")
        unless &can('rn', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'fname_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'fname_title2'}, "");
	print "<center><font size=+1>",&text('fmisc_for', $s),"</font></center>\n";
	}
&get_share($s);

print &ui_form_start("save_fname.cgi", "post");
print &ui_hidden("old_name", $s);
print &ui_table_start($text{'fname_option'}, undef, 2);

print &ui_table_row($text{'fname_manglecase'},
	&yesno_input("mangle case"));

print &ui_table_row($text{'fname_case'},
	&yesno_input("case sensitive"));

print &ui_table_row($text{'fname_defaultcase'},
	&ui_radio("default_case",
		  &getval("default case") =~ /lower/i ? "lower" : "upper",
		  [ [ "lower", $text{'fname_lower'} ],
		    [ "upper", $text{'fname_upper'} ] ]));

print &ui_table_row($text{'fname_preserve'},
	&yesno_input("preserve case"));

print &ui_table_row($text{'fname_shortpreserve'},
	&yesno_input("short preserve case"));

print &ui_table_row($text{'fname_hide'},
	&yesno_input("hide dot files"));

print &ui_table_row($text{'fname_archive'},
	&yesno_input("map archive"));

print &ui_table_row($text{'fname_hidden'},
	&yesno_input("map hidden"));

print &ui_table_row($text{'fname_system'},
	&yesno_input("map system"));

print &ui_table_end();
if (&can('wN', \%access, $in{'share'})) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

&ui_print_footer("edit_fshare.cgi?share=".&urlize($s), $text{'index_fileshare'},
	"", $text{'index_sharelist'});

