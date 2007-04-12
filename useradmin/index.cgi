#!/usr/local/bin/perl

require './user-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("passwd group shadow gshadow", "man"));
$formno = 0;
%access = &get_module_acl();

# Get the user and group lists
@allulist = &list_users();
@ulist = &list_allowed_users(\%access, \@allulist);
@allglist = &list_groups();
@glist = &list_allowed_groups(\%access, \@allglist);
foreach $g (@allglist) {
	$usedgid{$g->{'gid'}} = $g;
	}

# Show users list header
if (@ulist || $access{'ucreate'}) {
	print "<a name=users></a>\n";
	print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
	print "<td>".&ui_subheading($text{'index_users'})."</td>\n";
	if (@glist || $access{'gcreate'}) {
		print "<td align=right valign=top>",
		      "<a href=#groups>$text{'index_gjump'}</a></td>\n";
		}
	print "</tr></table>\n";
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
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
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
	if ($access{'icons'}) {
		# Show an icon for each user
		&show_user_buttons();
		local @icons = map { "images/user.gif" } @ulist;
		local @links = map { "edit_user.cgi?num=$_->{'num'}" } @ulist;
		local @titles = map { $_->{'user'} } @ulist;
		&icons_table(\@links, \@titles, \@icons, 5);
		}
	elsif ($config{'display_mode'} == 2) {
		# Show usernames under groups
		foreach $u (@ulist) {
			push(@{$ug{$u->{'gid'}}}, $u);
			}
		&show_user_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_ugroup'}</b></td> ",
		      "<td><b>$text{'index_users'}</b></td> </tr>\n";
		foreach $g (keys %ug) {
			print "<tr $cb> <td width=20%><b>",
			      &html_escape($usedgid{$g}->{'group'}),
			      "</b></td>\n";
			print "<td width=80%><table width=100% ",
			      "cellpadding=0 cellspacing=0>\n";
			$i = 0;
			foreach $u (@{$ug{$g}}) {
				if ($i%4 == 0) { print "<tr>\n"; }
				print "<td width=25%>",&user_link($u),"</td>\n";
				if ($i%4 == 3) { print "</tr>\n"; }
				$i++;
				}
			print "</table></td> </tr>\n";
			}
		print "</table>\n";
		}
	elsif ($config{'display_mode'} == 1) {
		# Show names, real names, home dirs and shells
		&users_table(\@ulist, $formno++, 0, 0, [ &get_user_buttons() ]);
		$no_user_buttons = 1;
		}
	else {
		# Just show names
		&show_user_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_users'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		for($i=0; $i<@ulist; $i++) {
			if ($i%4 == 0) { print "<tr>\n"; }
			print "<td width=25%>",&user_link($ulist[$i]),"</td>\n";
			if ($i%4 == 3) { print "</tr>\n"; }
			}
		print "</table></td> </tr></table>\n";
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
print "<p>\n";

if (@glist || $access{'gcreate'}) {
	print "<hr>\n";
	print "<a name=groups></a>\n";
	print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
	print "<td>".&ui_subheading($text{'index_groups'})."</td>\n";
	if (@ulist || $access{'ucreate'}) {
		print "<td align=right valign=top>",
		      "<a href=#users>$text{'index_ujump'}</a></td>\n";
		}
	print "</tr></table>\n";
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
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
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
	if ($access{'icons'}) {
		# Show an icon for each group
		&show_group_buttons();
		local @icons = map { "images/group.gif" } @glist;
		local @links = map { "edit_group.cgi?num=$_->{'num'}" } @glist;
		local @titles = map { $_->{'group'} } @glist;
		&icons_table(\@links, \@titles, \@icons, 5);
		}
	elsif ($config{'display_mode'} == 1) {
		# Display group name, ID and members
		&groups_table(\@glist, $formno++, 0, [ &get_group_buttons() ]);
		$no_group_buttons = 1;
		}
	else {
		# Just display group names
		&show_group_buttons();
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_groups'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		for($i=0; $i<@glist; $i++) {
			if ($i%4 == 0) { print "<tr>\n"; }
			print "<td width=25%>",
			      &group_link($glist[$i]),"</td>\n";
			if ($i%4 == 3) { print "</tr>\n"; }
			}
		print "</table></td> </tr></table>\n";
		}
	}
elsif ($access{'gcreate'} == 1) {
	print "<hr>\n";
	if (@allglist) {
		print "<b>$text{'index_notgroups'}</b>. <p>\n";
		}
	else {
		print "<b>$text{'index_notgroups2'}</b>. <p>\n";
		}
	}
&show_group_buttons() if (!$no_group_buttons);

if ($access{'logins'}) {
	print "<hr>\n";
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
print &ui_links_row(\@b);
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

