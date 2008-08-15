#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './user-lib.pl';
&ReadParse();

# Get group and show page header
$n = $in{'num'};
if ($n eq "") {
	$access{'gcreate'} == 1 || &error($text{'gedit_ecreate'});
	&ui_print_header(undef, $text{'gedit_title2'}, "", "create_group");
	}
else {
	@glist = &list_groups();
	%group = %{$glist[$n]};
	&can_edit_group(\%access, \%group) ||
		&error($text{'gedit_eedit'});
	&ui_print_header(undef, $text{'gedit_title'}, "", "edit_group");
	}
@ulist = &list_users();

&build_group_used(\%gused);

# Start of form
print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("num", $n) if ($n ne "");
print &ui_table_start($text{'gedit_details'}, "width=100%", 4);

# Group name
print &ui_table_row(&hlink($text{'gedit_group'}, "ggroup"),
	$n eq "" ? &ui_textbox("group", undef, 20)
		 : "<tt>$group{'group'}</tt>");

# Group ID
# XXX massively simplify!!
print "<td valign=middle>",&hlink("<b>$text{'gedit_gid'}</b>","ggid"),"</td>\n";
if ($n eq "") {
    print "<td>\n";
    $defgid = &allocate_gid(\%gused);

    if ( $access{'calcgid'} && $access{'autogid'} && $access{'usergid'} ) {
        # Show options for calculated, auto-incremented and user entered GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( $access{'calcgid'} && $access{'autogid'} && !$access{'usergid'} ) {
        # Show options for calculated and auto-incremented GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
    }

    if ( $access{'calcgid'} && !$access{'autogid'} && $access{'usergid'} ) {
        # Show options for calculated and user entered GID
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( !$access{'calcgid'} && $access{'autogid'} && $access{'usergid'} ) {
        # Show options for auto-incremented and user entered GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( $access{'calcgid'} && !$access{'autogid'} && !$access{'usergid'} ) {
        # Hidden field  for calculated GID
	print "<input type=hidden name=gid_def value=2>";
	print "$text{'gedit_gid_calc'} from Berkeley style cksum\n";
    }

    if ( !$access{'calcgid'} && $access{'autogid'} && !$access{'usergid'} ) {
        # Hidden field for auto-incremented GID
	print "<input type=hidden name=gid_def value=1>";
	print "$text{'gedit_gid_calc'}\n";
    }

    if ( !$access{'calcgid'} && !$access{'autogid'} && $access{'usergid'} ) {
        # Show field for user entered GID
	print "<input type=hidden name=gid_def value=0>";
	print "GID: <input name=gid size=10 value='$defgid'>\n";
    }

    if ( !$access{'calcgid'} && !$access{'autogid'} && !$access{'usergid'} ) {
        if ( $config{'gid_mode'} eq '0' ) {
          print "<input type=hidden name=gid_def value=0>";
          print "GID: <input name=gid size=10 value='$defgid'>\n";
        } else {
          print "<input type=hidden name=gid_def value=$config{'gid_mode'}>";
          print "$text{'gedit_gid_def'}\n" if ( $config{'gid_mode'} eq '1' );
          print "$text{'gedit_gid_calc'}\n" if ( $config{'gid_mode'} eq '2' );
        }
    }
    print "</td></tr>\n";
	}
else {
	print "<td valign=top><input name=gid size=10 ",
	      "value=\"$group{'gid'}\"></td>\n";
	}
print "</tr>\n";

# Group password (rarely used, but..)
print &ui_table_row(&hlink($text{'pass'}, "gpasswd"),
	&ui_radio_table("passmode", $group{'pass'} eq "" ? 0 : 1,
		[ [ 0, $text{'none2'} ],
		  [ 1, $text{'encrypted'},
		       &ui_textbox("encpass", $group{'pass'}, 20) ],
		  [ 2, $text{'clear'},
		       &ui_textbox("pass", undef, 15) ] ]));

# Member chooser
# XXX doesn't work yet!
print &ui_table_row(&hlink($text{'gedit_members'}, "gmembers"),
	&ui_multi_select("members",
		[ map { [ $_, $_ ] } split(/,/ , $group{'members'}) ],
		[ map { [ $_->{'user'}, $_->{'user'} ] } @ulist ],
		10, 1));

# Section for on-change and on-create events
if ($n ne "") {
	if ($access{'chgid'} == 1 || $access{'mothers'} == 1) {
		print &ui_table_start($text{'onsave'}, "width=100%", 2);

		# Change file GIDs on save
		if ($access{'chgid'} == 1) {
			print &ui_table_row(
				&hlink($text{'chgid'}, "gchgid"),
				&ui_radio("chgid", 0,
				  [ [ 0, $text{'no'} ],
				    [ 1, $text{'gedit_homedirs'} ],
				    [ 2, $text{'gedit_allfiles'} ] ]));
			}

		# Update in other modules?
		if ($access{'mothers'} == 1) {
			print &ui_table_row(
				&hlink($text{'gedit_mothers'}, "others"),
				&ui_radio("others", $config{'default_other'},
					  [ [ 1, $text{'yes'} ],
					    [ 0, $text{'no'} ] ]));
			}

		print &ui_table_end();
		}
	}
else {
	if ($access{'cothers'} == 1) {
		print &ui_table_start($text{'uedit_oncreate'}, "width=100%", 2);

		# Create in other modules?
		print &ui_table_row(
			&hlink($text{'gedit_cothers'}, "others"),
			&ui_radio("others", $config{'default_other'},
				  [ [ 1, $text{'yes'} ],
				    [ 0, $text{'no'} ] ]));

		print &ui_table_end();
		}
	}

# Save/delete/create buttons
if ($n ne "") {
	print &ui_form_end([
		[ undef, $text{'save'} ],
		$access{'gdelete'} ? ( [ 'delete', $text{'delete'} ] ) : ( ),
		]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?mode=groups", $text{'index_return'});

