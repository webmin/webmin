#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
if ($in{'new'}) {
	$access{'gcreate'} || &error($text{'gedit_ecreate'});
	&ui_print_header(undef, $text{'gedit_title2'}, "");
	}
else {
	$rv = $ldap->search(base => $in{'dn'},
			    scope => 'base',
			    filter => &group_filter());
	($ginfo) = $rv->all_entries;
	$group = $ginfo->get_value('cn');
	$gid = $ginfo->get_value('gidNumber');
	$pass = $ginfo->get_value('userPassword');
	$desc = $ginfo->get_value('description');
	@members = $ginfo->get_value('memberUid');
	foreach $oc ($ginfo->get_value('objectClass')) {
		$oclass{$oc} = 1;
		}
	%ginfo = &dn_to_hash($ginfo);
	&can_edit_group(\%ginfo) || &error($text{'gedit_eedit'});
	&ui_print_header(undef, $text{'gedit_title'}, "");
	}

# Build list of all possible users
@ulist = &useradmin::list_users();
%ulistdone = map { $_->{'user'}, 1 } @ulist;
push(@ulist, grep { !$ulistdone{$_->{'user'}} } &list_users());

# Start of form
print &ui_form_start("save_group.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("dn", $in{'dn'});
print &ui_table_start($text{'gedit_details'}, "width=100%", 2, [ "width=30%" ]);

# Current DN and classes
if (!$in{'new'}) {
	print &ui_table_row($text{'gedit_dn'},
		"<tt>$in{'dn'}</tt>");

	print &ui_table_row($text{'uedit_classes'},
		join(" , ", map { "<tt>$_</tt>" }
                        $ginfo->get_value('objectClass')));
        }

# Group name
print &ui_table_row($text{'gedit_group'},
	&ui_textbox("group", $group, 20));

# Group ID
if ($in{'new'}) {
	# Next GID comes from LDAP only
	$newgid = $mconfig{'base_gid'};
	while(&check_gid_used($ldap, $newgid)) {
		$newgid++;
		}
	$gidfield = &ui_textbox("gid", $newgid, 10);
	}
else {
	$gidfield = &ui_textbox("gid", $gid, 10);
	}
print &ui_table_row($text{'gedit_gid'},
	$gidfield);

# Description
print &ui_table_row($text{'gedit_desc'},
	&ui_textbox("desc", $desc, 40));

# Group password (rarely used, but..)
print &ui_table_row($text{'pass'},
	&ui_radio_table("passmode", $pass eq "" ? 0 : 1,
		[ [ 0, $text{'none2'} ],
		  [ 1, $text{'encrypted'},
		       &ui_textbox("encpass", $pass, 20) ],
		  [ 2, $text{'clear'},
		       &ui_textbox("pass", undef, 15) ] ]));

# Member chooser
if ($config{'membox'} == 0) {
	# Nicer left/right chooser
	print &ui_table_row($text{'gedit_members'},
		&ui_multi_select("members",
			[ map { [ $_, $_ ] } @members ],
			[ map { [ $_->{'user'}, $_->{'user'} ] } @ulist ],
			10, 1, 0,
			$text{'gedit_allu'}, $text{'gedit_selu'}, 150));
	}
else {
	# Text box
	print &ui_table_row($text{'gedit_members'},
		&ui_textarea("members", join("\n", @members), 5, 30));
	}

print &ui_table_end();

# Show extra fields (if any)
&extra_fields_input($config{'group_fields'}, $ginfo, \@tds);

# Show capabilties section
print &ui_table_start($text{'gedit_cap'}, "width=100%", 4, [ "width=30%" ]);

# Samba group?
print &ui_table_row($text{'gedit_samba'},
	&ui_yesno_radio("samba", $oclass{$samba_group_class}));

print &ui_table_end();

# Show section for on-save or on-creation options
if (!$in{'new'}) {
	print &ui_table_start($text{'onsave'}, "width=100%", 2,
			      [ "width=30%" ]);

	# Change GID on save
	print &ui_table_row($text{'chgid'},
		&ui_radio("chgid", 0,
		  [ [ 0, $text{'no'} ],
		    [ 1, $text{'gedit_homedirs'} ],
		    [ 2, $text{'gedit_allfiles'} ] ]));


	# Update in other modules?
	print &ui_table_row($text{'gedit_mothers'},
		&ui_radio("others", $mconfig{'default_other'},
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ] ]));

	print &ui_table_end();
	}
else {
	print &ui_table_start($text{'uedit_oncreate'}, "width=100%", 2,
			      [ "width=30%" ]);

	# Create in other modules?
	print &ui_table_row($text{'gedit_cothers'},
		&ui_radio("others", $mconfig{'default_other'},
			  [ [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ] ]));

	print &ui_table_end();
	}

# Save/delete/create buttons
if (!$in{'new'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'raw', $text{'uedit_raw'} ],
			     [ 'delete', $text{'delete'} ],
			   ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?mode=groups", $text{'index_greturn'});

