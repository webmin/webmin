#!/usr/local/bin/perl

require './user-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("passwd group shadow gshadow", "man"));
$formno = 0;
%access = &get_module_acl();
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

if (@ulist > $config{'display_max'}) {
	# Display user search form
	print "<b>$text{'index_toomany'}</b><p>\n";
	print "<form action=search_user.cgi>\n";
	print &hlink("<b>$text{'index_find'}</b>","findform"),
	      " <select name=field>\n";
	print "<option value=user selected>$text{'user'}\n";
	print "<option value=real>$text{'real'}\n";
	print "<option value=shell>$text{'shell'}\n";
	print "<option value=home>$text{'home'}\n";
	print "<option value=uid>$text{'uid'}\n";
	print "<option value=group>$text{'gid'}\n";
	print "<option value=gid>$text{'gidnum'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0>$text{'index_equals'}\n";
	print "<option value=4 checked>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "<option value=6>$text{'index_lower'}\n";
	print "<option value=7>$text{'index_higher'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
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

if (@glist > $config{'display_max'}) {
	# Display group search form
	print "<b>$text{'index_gtoomany'}</b><p>\n";
	print "<form action=search_group.cgi>\n";
	print &hlink("<b>$text{'index_gfind'}</b>","gfindform"),
	      " <select name=field>\n";
	print "<option value=group selected>$text{'gedit_group'}\n";
	print "<option value=members>$text{'gedit_members'}\n";
	print "<option value=gid>$text{'gedit_gid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0>$text{'index_equals'}\n";
	print "<option value=4 checked>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "<option value=6>$text{'index_lower'}\n";
	print "<option value=7>$text{'index_higher'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
	$formno++;
	}
elsif (@glist) {
	@glist = &sort_groups(\@glist, $config{'sort_mode'});
	if ($config{'display_mode'} == 1) {
		# Display group name, ID and members
		&groups_table(\@glist, $formno++, 0, [ &get_group_buttons() ]);
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
	print &ui_hr();
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
print &ui_tabs_end();

if ($access{'logins'}) {
	print &ui_hr();
	print "<table width=100%><tr>\n";
	print "<form action=list_logins.cgi>\n";
	print "<td><input type=submit value=\"$text{'index_logins'}\">\n";
	print "<input name=username size=8> ",
	      &user_chooser_button("username",0,$formno),"</td></form>\n";

	if (defined(&logged_in_users)) {
		print "<form action=list_who.cgi>\n";
		print "<td align=right><input type=submit ",
		      "value=\"$text{'index_who'}\"></td></form>\n";
		}
	print "</tr></table>\n";
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
		push(@rv, "<a href=\"edit_user.cgi\">".
		      	  "$text{'index_createuser'}</a>");
		}
	else {
		push(@rv, $text{'index_nomoreusers'});
		}
	}
push(@rv, "<a href=\"batch_form.cgi\">$text{'index_batch'}</a>")
	if ($access{'batch'});
push(@rv, "<a href=\"export_form.cgi\">$text{'index_export'}</a>")
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
		push(@rv, "<a href=\"edit_group.cgi\">$text{'index_creategroup'}</a>");
		}
	else {
		push(@rv, $text{'index_nomoregroups'});
		}
	}
return @rv;
}

sub show_group_buttons
{
local @b = &get_group_buttons();
print &ui_links_row(\@b);
}

