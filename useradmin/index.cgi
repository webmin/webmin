#!/usr/local/bin/perl

require './user-lib.pl';

# Show header with password DB type
$pft = &passfiles_type();
$pftmsg = &text('index_pft', $text{'index_pft'.$pft} || $pft);
&ui_print_header($pftmsg, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("passwd group shadow gshadow", "man"));

$formno = 0;
&ReadParse();

@quarters = ( "width=25%", "width=25%", "width=25%", "width=25%" );

# Get the user and group lists
@allulist = &list_users();
@ulist = &list_allowed_users(\%access, \@allulist);
@allglist = &list_groups();
@glist = &list_allowed_groups(\%access, \@allglist);
foreach $g (@allglist) {
	$usedgid{$g->{'gid'}} = $g;
	}

# Start of tabs, based on what can be edited
@tabs = ( );
if (@ulist || $access{'ucreate'}) {
	push(@tabs, [ "users", $text{'index_users'},
		      "index.cgi?mode=users" ]);
	$can_users = 1;
	}
if (@glist || $access{'gcreate'}) {
	push(@tabs, [ "groups", $text{'index_groups'},
		      "index.cgi?mode=groups" ]);
	$can_groups = 1;
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

# Start of users tab
if ($can_users) {
	print &ui_tabs_start_tab("mode", "users");
	}

if ($config{'display_mode'} != 1 &&
    @ulist > $config{'display_max'}) {
	# Display advanced search form
	print "<b>$text{'index_toomany'}</b><p>\n";
	print &ui_form_start("search_user.cgi");
	print &ui_table_start($text{'index_usheader'}, undef, 2);

	# Field to search
	print &ui_table_row($text{'index_find'},
		&ui_select("field", "userreal",
			   [ [ "userreal", $text{'index_userreal'} ],
			     [ "user", $text{'user'} ],
			     [ "real", $text{'real'} ],
			     [ "shell", $text{'shell'} ],
			     [ "home", $text{'home'} ],
			     [ "uid", $text{'uid'} ],
			     [ "group", $text{'group'} ],
			     [ "gid", $text{'gid'} ] ])." ".
		&ui_select("match", 4, $match_modes));

	# Text
	print &ui_table_row($text{'index_ftext'},
		&ui_textbox("what", undef, 50));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'find'} ] ]);
	$formno++;
	}
elsif (@ulist) {
	# Display a table of all users
	@ulist = &sort_users(\@ulist, $config{'sort_mode'});
	if ($config{'display_mode'} == 2) {
		# Show usernames under groups
		foreach $u (@ulist) {
			push(@{$ug{$u->{'gid'}}}, $u);
			}
		@table = ( );
		foreach $g (sort { $usedgid{$a}->{'group'} cmp
				   $usedgid{$b}->{'group'} } keys %ug) {
			@grid = map { &user_link($_) } @{$ug{$g}};
			push(@table, [ &html_escape($usedgid{$g}->{'group'}),
			       &ui_grid_table(\@grid, 4, 100, \@quarters) ]);
			}
		print &ui_columns_table(
			[ $text{'index_ugroup'}, $text{'index_users'} ],
			100,
			\@table,
			);
		}
	elsif ($config{'display_mode'} == 1) {
		# Show names, real names, home dirs and shells
		@b = &get_user_buttons();
		@left = grep { !/batch_form|export_form/ } @b;
		@right = grep { /batch_form|export_form/ } @b;
		&users_table(\@ulist, $formno++, 0, 0, \@left, \@right);
		$no_user_buttons = 1;
		}
	else {
		# Just show names
		@grid = map { &user_link($_) } @ulist;
		print &ui_grid_table(\@grid, 4, 100, \@quarters,
			undef, $text{'index_users'});
		}
	}
elsif ($access{'ucreate'}) {
	if (@allulist) {
		print "<b>$text{'index_notusers'}</b>. <p>\n";
		}
	else {
		print "<b>$text{'index_notusers2'}</b>. <p>\n";
		}
	}
&show_user_buttons() if (!$no_user_buttons);

# End of users tab
if ($can_users) {
	print &ui_tabs_end_tab("mode", "users");
	}

# Start of groups tab
if ($can_groups) {
	print &ui_tabs_start_tab("mode", "groups");
	}

if ($config{'display_mode'} != 1 &&
    @glist > $config{'display_max'}) {
	# Display group search form
	print "<b>$text{'index_gtoomany'}</b><p>\n";
	print &ui_form_start("search_group.cgi");
	print &ui_table_start($text{'index_gsheader'}, undef, 2);

	# Field to search
	print &ui_table_row($text{'index_gfind'},
		&ui_select("field", "group",
			   [ [ "group", $text{'gedit_group'} ],
			     [ "members", $text{'gedit_members'} ],
			     [ "gedit_gid", $text{'gedit_gid'} ] ])." ".
		&ui_select("match", 4, $match_modes));

	# Text
	print &ui_table_row($text{'index_ftext'},
		&ui_textbox("what", undef, 50));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'find'} ] ]);
	$formno++;
	}
elsif (@glist) {
	@glist = &sort_groups(\@glist, $config{'sort_mode'});
	if ($config{'display_mode'} == 1) {
		# Display group name, ID and members
		@b = &get_group_buttons();
		@left = grep { !/gbatch_form|gexport_form/ } @b;
		@right = grep { /gbatch_form|gexport_form/ } @b;
		&groups_table(\@glist, $formno++, 0, \@left, \@right);
		$no_group_buttons = 1;
		}
	else {
		# Just display group names
		@grid = map { &group_link($_) } @glist;
		print &ui_grid_table(\@grid, 4, 100, \@quarters,
			undef, $text{'index_groups'});
		}
	}
elsif ($access{'gcreate'} == 1) {
	if (@allglist) {
		print "<b>$text{'index_notgroups'}</b>. <p>\n";
		}
	else {
		print "<b>$text{'index_notgroups2'}</b>. <p>\n";
		}
	}
&show_group_buttons() if (!$no_group_buttons);

# End of groups tab
if ($can_groups) {
	print &ui_tabs_end_tab("mode", "groups");
	}
print &ui_tabs_end(1);

# Buttons to show recent logins and logged-in users
if ($access{'logins'}) {
	print &ui_hr();
	print &ui_buttons_start();

	# Show recent logins
	print &ui_buttons_row(
		"list_logins.cgi",
		$text{'index_logins'},
		$text{'index_loginsdesc'},
		undef,
		&ui_radio("username_def", 1,
		  [ [ 1, $text{'index_loginsall'} ],
		    [ 0, $text{'index_loginsuser'}." ".
			 &ui_user_textbox("username", undef, $formno) ] ]));

	# Show currently logged in user
	if (defined(&logged_in_users)) {
		print &ui_buttons_row(
			"list_who.cgi",
			$text{'index_who'},
			$text{'index_whodesc'},
			);
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
 
sub get_user_buttons
{
local @rv;
if ($access{'ucreate'}) {
	local $cancreate;
	if ($access{'hiuid'} && !$access{'umultiple'}) {
		foreach $u (@allulist) {
			$useduid{$u->{'uid'}}++;
			}
		for($i=int($access{'lowuid'}); $i<=$access{'hiuid'}; $i++) {
			if (!$useduid{$i}) {
				$cancreate = 1;
				last;
				}
			}
		}
	else { $cancreate = 1; }
	if ($cancreate) {
		push(@rv, &ui_link("edit_user.cgi", $text{'index_createuser'}) );
		}
	else {
		push(@rv, $text{'index_nomoreusers'});
		}
	}
push(@rv, &ui_link("batch_form.cgi", $text{'index_batch'}) )
	if ($access{'batch'});
push(@rv, &ui_link("export_form.cgi", $text{'index_export'}) )
	if ($access{'export'});
return @rv;
}

sub show_user_buttons
{
local @b = &get_user_buttons();
local @left = grep { !/batch_form|export_form/ } @b;
local @right = grep { /batch_form|export_form/ } @b;
local @grid = ( &ui_links_row(\@left), &ui_links_row(\@right) );
print &ui_grid_table(\@grid, 2, 100, [ "align=left", "align=right" ]);
}

sub get_group_buttons
{
local @rv;
if ($access{'gcreate'} == 1) {
	local $cancreate;
	if ($access{'higid'} && !$access{'gmultiple'}) {
		for($i=int($access{'lowgid'}); $i<=$access{'higid'}; $i++) {
			if (!$usedgid{$i}) {
				$cancreate = 1;
				last;
				}
			}
		}
	else { $cancreate = 1; }
	if ($cancreate) {
		push(@rv, &ui_link("edit_group.cgi", $text{'index_creategroup'}) );
		}
	else {
		push(@rv, $text{'index_nomoregroups'});
		}
	}
push(@rv, &ui_link("gbatch_form.cgi", $text{'index_batch'}) )
	if ($access{'batch'});
push(@rv, &ui_link("gexport_form.cgi", $text{'index_export'}) )
	if ($access{'export'});
return @rv;
}

sub show_group_buttons
{
local @b = &get_group_buttons();
local @left = grep { !/gbatch_form|gexport_form/ } @b;
local @right = grep { /gbatch_form|gexport_form/ } @b;
local @grid = ( &ui_links_row(\@left), &ui_links_row(\@right) );
print &ui_grid_table(\@grid, 2, 100, [ "align=left", "align=right" ]);
}

