#!/usr/local/bin/perl
# edit_pshare.cgi
# Display a form for editing or creating a new printer share

require './samba-lib.pl';
&ReadParse();
$s = $in{'share'};
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
if(!$s) {
	&error("$text{'eacl_np'} $text{'eacl_pcps'}")
        unless $access{'c_ps'};
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_paps'}")
        unless &can('r', \%access, $in{'share'});
	}
# display
if ($s) {
	&ui_print_header(undef, $s eq 'global' ? $text{'pshare_title1'} : $text{'pshare_title2'}, "");
	&get_share($s);
	}
else {
	&ui_print_header(undef, $text{'pshare_title3'}, "");
	}

print &ui_form_start("save_pshare.cgi", "post");
if ($s) {
	print &ui_hidden("old_name", $s);
	}

# Vital share options..
print &ui_table_start($text{'pshare_info'}, undef, 2);
if ($s ne "global") {
	if ($copy = &getval("copy")) {
		print &ui_table_row(undef, &text('share_copy', $copy), 2);
		}
	print &ui_table_row($text{'pshare_name'},
		&ui_radio("printers", $s eq "printers" ? 1 : 0,
		  [ [ 0, &ui_textbox("share", $s eq "printers" ? "" : $s, 20) ],
		    [ 1, $text{'pshare_all'} ] ]));
	}

if (&foreign_check("lpadmin")) {
	&foreign_require("lpadmin", "lpadmin-lib.pl");
	@plist = &foreign_call("lpadmin", "list_printers");
	}
elsif ($config{'list_printers_command'}) {
	@plist = split(/\s+/ , `$config{'list_printers_command'}`);
	}
if (@plist) {
	local $printer = &getval("printer");
	push(@plist, $printer)
		if ($printer && &indexof($printer, @plist) == -1);
	@opts = ( );
	push(@opts, [ "", $s eq "global" ? $text{'config_none'}
					 : $text{'default'} ]);
	foreach $p (@plist) {
		push(@opts, [ $p, $p ]);
		}
	print &ui_table_row($text{'pshare_unixprn'},
		&ui_select("printer", $printer, \@opts));
	}
else {
	print &ui_table_row($text{'pshare_unixprn'},
		&ui_textbox("printer", undef, 15));
	}

print &ui_table_row($text{'pshare_spool'},
	&ui_textbox("path", &getval("path"), 60)." ".
	&file_chooser_button("path", 1));

print &ui_table_row($text{'share_available'},
	&yesno_input("available"));

print &ui_table_row($text{'share_browseable'},
	&yesno_input("browseable"));

print &ui_table_row($text{'share_comment'},
	&ui_textbox("comment", &getval("comment"), 60));

if ($s eq "global") {
	print &ui_table_row(undef, $text{'share_samedesc1'}, 2);
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
	$us = "share=".&urlize($s)."&printer=1";
	local (@url, @text, @icon, $disp);
	if (&can('rs',\%access, $s)) {
		push(@url,  "edit_sec.cgi?$us");
		push(@text, $text{'share_security'});
		push(@icon, "images/icon_2.gif");
		$disp++;
		}
	if (&can('ro',\%access, $s)) {
		push(@url,  "edit_popts.cgi?$us");
		push(@text, $text{'print_option'});
		push(@icon, "images/icon_3.gif");
		$disp++;
        }
	if ($disp) {
		print &ui_hr();
		print &ui_subheading($text{'share_option'});
		&icons_table(\@url, \@text, \@icon);
		}
	}

&ui_print_footer("", $text{'index_sharelist'});
