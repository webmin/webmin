#!/usr/local/bin/perl
# edit_sec.cgi
# Edit security options for some file or print share

require './samba-lib.pl';
&ReadParse();
# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pvsec'}")
        unless &can('rs', \%access, $in{'share'});
# display
$s = $in{'share'};
if ($s eq "global") {
	&ui_print_header(undef, $text{'sec_index1'}, "");
	}
else {
	&ui_print_header(undef, $text{'sec_index2'}, "");
	print "<center><font size=+1>",&text('fmisc_for', $s), "</font></center>\n";
	}
&get_share($s);

print &ui_form_start("save_sec.cgi", "post");
print &ui_hidden("old_name", $s);
print &ui_hidden("printer", $in{'printer'});
print &ui_table_start($text{'share_security'}, undef, 2);

print &ui_table_row($text{'sec_writable'},
	&yesno_input("writeable"));

print &ui_table_row($text{'sec_guest'},
	&ui_radio("guest", &istrue("public") && &istrue("guest only") ? 2 :
			   &istrue("public") && !&istrue("guest only") ? 1 : 0,
		  [ [ 0, $text{'config_none'} ],
		    [ 1, $text{'yes'} ],
		    [ 2, $text{'sec_guestonly'} ] ]));

print &ui_table_row($text{'sec_guestaccount'},
	&username_input("guest account", "Default"));

print &ui_table_row($text{'sec_limit'},
	&yesno_input("only user"));

print &ui_table_row($text{'sec_allowhost'},
	&ui_opt_textbox("allow_hosts", &getval("allow hosts"), 60,
			$text{'config_all'}, $text{'sec_onlyallow'}));

print &ui_table_row($text{'sec_denyhost'},
	&ui_opt_textbox("deny_hosts", &getval("deny hosts"), 60,
			$text{'config_none'}, $text{'sec_onlydeny'}));

print &ui_table_row($text{'sec_revalidate'},
	&yesno_input("revalidate"));

foreach $f ("valid users", "invalid users") {
	@user = &split_users(&getval($f));
	($uf = $f) =~ s/ /_/g;
	($pfx) = split(/\s+/, $f);
	print &ui_table_row($text{'sec_'.$pfx.'user'},
		&ui_textbox($uf."_u",
			    join(' ', grep { !/^@/ } @user), 60)." ".
		&user_chooser_button($uf."_u", 1));

	print &ui_table_row($text{'sec_'.$pfx.'group'},
		&ui_textbox($uf."_g", join(' ', map { s/@//; $_ } grep { /^@/ } @user), 60)." ".
		&group_chooser_button($uf."_g", 1));
	}

print &ui_table_hr();

foreach $fp ([ "user", "possible" ],
	    [ "read list", "ro" ],
	    [ "write list", "rw" ]) {
	($f, $pfx) = @$fp;
	($uf = $f) =~ s/ /_/g;
	@user = &split_users(&getval($f));
	print &ui_table_row($text{'sec_'.$pfx.'user'},
		&ui_textbox($uf."_u", join(' ', grep { !/^@/ } @user), 60)." ".
		&user_chooser_button($uf."_u", 1));
	print &ui_table_row($text{'sec_'.$pfx.'group'},
		&ui_textbox($uf."_g", join(' ', map { s/@//;$_ } grep { /^@/ } @user), 60)." ".
		&group_chooser_button($uf."_g", 1));
	}

print &ui_table_end();

if (&can('wS', \%access, $in{'share'})) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

if (&istrue("printable") || $in{'printer'}) {
	&ui_print_footer("edit_pshare.cgi?share=".&urlize($s),
			 $text{'index_printershare'},
			 "", $text{'index_sharelist'});
	}
else {
	&ui_print_footer("edit_fshare.cgi?share=".&urlize($s),
			 $text{'index_fileshare'},
			 "", $text{'index_sharelist'});
	}


sub split_users
{
return split(/\s*,\s*/, $_[0]);
}

