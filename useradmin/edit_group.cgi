#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './user-lib.pl';
&ReadParse();
@glist = &list_groups();

# Get group and show page header
$n = $in{'group'};
if ($n eq "") {
	$access{'gcreate'} == 1 || &error($text{'gedit_ecreate'});
	&ui_print_header(undef, $text{'gedit_title2'}, "", "create_group");
	if ($in{'clone'} ne '') {
		($clone_hash) = grep { $_->{'group'} eq $in{'clone'} } @glist;
		$clone_hash || &error($text{'ugdit_egone'});
		%group = %$clone_hash;
		&can_edit_user(\%access, \%group) ||
			&error($text{'gedit_eedit'});
		$group{'group'} = '';
		}
	}
else {
	($ginfo_hash) = grep { $_->{'group'} eq $n } @glist;
	$ginfo_hash || &error($text{'gedit_egone'});
	%group = %$ginfo_hash;
	&can_edit_group(\%access, \%group) ||
		&error($text{'gedit_eedit'});
	&ui_print_header(undef, $text{'gedit_title'}, "", "edit_group");
	}
@ulist = &list_users();

&build_group_used(\%gused);

# Start of form
print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("old", $n) if ($n ne "");
print &ui_table_start($text{'gedit_details'}, "width=100%", 2, [ "width=30%" ]);

# Group name
print &ui_table_row(&hlink($text{'gedit_group'}, "ggroup"),
	$n eq "" ? &ui_textbox("group", undef, 20)
		 : "<tt>".&html_escape($group{'group'})."</tt>");

# Group ID
if ($n ne "") {
	# Existing group, just show field to edit
	$gidfield = &ui_textbox("gid", $group{'gid'}, 10);
	}
else {
	# Work out which GID modes are available
	@gidmodes = ( );
	$defgid = &allocate_gid(\%gused);
	if ($access{'autogid'}) {
		push(@gidmodes, [ 1, $text{'gedit_gid_def'} ]);
		}
	if ($access{'calcgid'}) {
		push(@gidmodes, [ 2, $text{'gedit_gid_calc'} ]);
		}
	if ($access{'usergid'}) {
		push(@gidmodes, [ 0, &ui_textbox("gid", $defgid, 10) ]);
		}
	if (@gidmodes == 1) {
		$gidfield = &ui_hidden("gid_def", $gidmodes[0]->[0]).
			    $gidmodes[0]->[1];
		}
	else {
		$gidfield = &ui_radio("gid_def", $config{'gid_mode'},
				      \@gidmodes);
		}
	}
print &ui_table_row(&hlink($text{'gedit_gid'}, "ggid"), $gidfield);

# Group password (rarely used, but..)
print &ui_table_row(&hlink($text{'pass'}, "gpasswd"),
	&ui_radio_table("passmode", $group{'pass'} eq "" ? 0 : 1,
		[ [ 0, $text{'none2'} ],
		  [ 1, $text{'encrypted'},
		       &ui_textbox("encpass", $group{'pass'}, 20) ],
		  [ 2, $text{'clear'},
		       &ui_textbox("pass", undef, 15) ] ]));

# Member chooser
@ulist = &sort_users(\@ulist, $config{'sort_mode'});
if ($config{'membox'} == 0) {
	# Nicer left/right chooser
	print &ui_table_row(&hlink($text{'gedit_members'}, "gmembers"),
		&ui_multi_select("members",
			[ map { [ $_, $_ ] }
			      sort { lc($a) cmp lc($b) }
				   split(/,/ , &html_escape($group{'members'})) ],
			[ map { [ $_->{'user'}, &html_escape($_->{'user'}) ] } @ulist ],
			10, 1, 0,
			$text{'gedit_allu'}, $text{'gedit_selu'}, 150));
	}
else {
	# Text box
	print &ui_table_row(&hlink($text{'gedit_members'}, "gmembers"),
		&ui_textarea("members",
			     join("\n", split(/,/ , $group{'members'})),
			     5, 30));
	}

# Primary members (read-only)
if ($n ne "") {
	@upri = grep { $_->{'gid'} == $group{'gid'} } @ulist;
	if (@upri) {
		@uprilinks = ( );
		foreach $u (@upri) {
			if (&can_edit_user(\%access, $u)) {
				push(@uprilinks, &ui_link("edit_user.cgi?".
				  "user=$u->{'user'}", &html_escape($u->{'user'}) ) );
				}
			else {
				push(@uprilinks, $u->{'user'});
				}
			}
		$upri = &ui_links_row(\@uprilinks);
		}
	else {
		$upri = $text{'gedit_prinone'};
		}
	print &ui_table_row(&hlink($text{'gedit_pri'}, "gpri"), $upri, 3);
	}

print &ui_table_end();

# Section for on-change and on-create events
if ($n ne "") {
	if ($access{'chgid'} == 1 || $access{'mothers'} == 1) {
		print &ui_table_start($text{'onsave'}, "width=100%", 2,
				      [ "width=30%" ]);

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
		print &ui_table_start($text{'uedit_oncreate'}, "width=100%", 2,
				      [ "width=30%" ]);

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
		$access{'gcreate'} ? ( [ 'clone', $text{'gedit_clone'} ] ) : (),
		$access{'gdelete'} ? ( [ 'delete', $text{'delete'} ] ) : (),
		]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?mode=groups", $text{'index_return'});

