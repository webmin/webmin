#!/usr/local/bin/perl
# edit_fshare.cgi
# Display a form for editing or creating a new directory share

require './samba-lib.pl';
&ReadParse();
$s = $in{'share'};
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if(!$s) {
    &error("$text{'eacl_np'} $text{'eacl_pcfs'}")
	    unless $access{'c_fs'};
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pafs'}")
        unless &can('r', \%access, $in{'share'});
    }
# display
if ($s) {
	&ui_print_header(undef, $s eq 'global' ? $text{'share_title1'} : $text{'share_title2'}, "");
	&get_share($s);
	}
else {
	&ui_print_header(undef, $text{'share_title3'}, "");
	}

print &ui_form_start("save_fshare.cgi", "post");
if ($s) {
	print &ui_hidden("old_name", $s);
	}

# Vital share options..
print &ui_table_start($text{'share_info'}, undef, 2);
if ($s ne "global") {
	if ($copy = &getval("copy")) {
		print &ui_table_row(undef, &text('share_copy', $copy), 2);
		}

	print &ui_table_row($text{'share_name'},
		&ui_radio("homes", $s eq "homes" ? 1 : 0,
		  [ [ 0, &ui_textbox("share", $s eq "homes" ? "" : $s, 20) ],
		    [ 1, $text{'share_home'} ] ]));
	}

print &ui_table_row($text{'share_dir'},
	&ui_textbox("path", &getval("path"), 60)." ".
	&file_chooser_button("path", 1));

if (!$s) {
	print &ui_table_row($text{'share_create'},
		&yesno_input("create"));

	print &ui_table_row($text{'share_owner'},
		&ui_user_textbox("createowner", "root"));

	print &ui_table_row($text{'share_createperms'},
		&ui_textbox("createperms", "755", 5));

	print &ui_table_row($text{'share_group'},
		&ui_group_textbox("creategroup", "root"));
	}

print &ui_table_row($text{'share_available'},
	&yesno_input("available"));

print &ui_table_row($text{'share_browseable'},
	&yesno_input("browseable"));

print &ui_table_row($text{'share_comment'},
	&ui_textbox("comment", &getval("comment"), 60));

if ($s eq "global") {
	print &ui_table_row(undef, $text{'share_samedesc2'}, 2);
	}

print &ui_table_end();
@buts = ( );
if ($s eq "global") {
	push(@buts, [ undef, $text{'save'} ]);
	}
elsif ($s) {
	if (&can('rw', \%access, $s)) {
		push(@buts, [ undef, $text{'save'} ]);
		}
	if (&can('rv', \%access, $s)) {
		push(@buts, [ "view", $text{'share_view'} ]);
		}
	if (&can('rw', \%access, $s)) {
		push(@buts, [ "delete", $text{'delete'} ]);
		}
	}
else {
	push(@buts, [ undef, $text{'create'} ]);
	}
print &ui_form_end(\@buts);

if ($s) {
	# Icons for other share options
	$us = "share=".&urlize($s);
	local (@url, @text, @icon, $disp);
	if (&can('rs',\%access, $s)) {
		push(@url,  "edit_sec.cgi?$us");
		push(@text, $text{'share_security'});
		push(@icon, "images/icon_2.gif");
		$disp++;
		}
	if (&can('rp',\%access, $s)) {
		push(@url,  "edit_fperm.cgi?$us");
		push(@text, $text{'share_permission'});
		push(@icon, "images/icon_7.gif");
		$disp++;
		}
	if (&can('rn',\%access, $s)) {
		push(@url,  "edit_fname.cgi?$us");
		push(@text, $text{'share_naming'});
		push(@icon, "images/icon_8.gif");
		$disp++;
		}
	if (&can('ro',\%access, $s)) {
		push(@url,  "edit_fmisc.cgi?$us");
		push(@text, $text{'share_misc'});
		push(@icon, "images/icon_4.gif");
		$disp++;
		}
	if ($disp) {
		print &ui_hr();
		print &ui_subheading($text{'share_option'});
		&icons_table(\@url, \@text, \@icon);
		}
	}

&ui_print_footer("", $text{'index_sharelist'});

