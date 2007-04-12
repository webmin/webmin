#!/usr/local/bin/perl
# index.cgi
# List all webmin users

require './acl-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

@glist = &list_groups();
foreach $g (@glist) {
	foreach $gm (@{$g->{'members'}}) {
		$ingroup{$gm} = $g;
		}
	}

@ulist = &list_users();
foreach $u (@ulist) {
	$me = $u if ($u->{'name'} eq $base_remote_user);
	}
@mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
	$access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
			       &list_modules();
map { $mcan{$_}++ } @mcan;

if ($config{'order'}) {
	@ulist = sort { $a->{'name'} cmp $b->{'name'} } @ulist;
	@glist = sort { $a->{'name'} cmp $b->{'name'} } @glist;
	}

foreach $m (&list_module_infos()) {
	$modname{$m->{'dir'}} = $m->{'desc'};
	}
@canulist = grep { &can_edit_user($_->{'name'}, \@glist) } @ulist;
if (!@canulist) {
	# If no users, only show section heading if can create
	if ($access{'create'}) {
		print &ui_subheading($text{'index_users'})
			if (!$config{'display'});
		print "<b>$text{'index_nousers'}</b><p>\n";
		print "<a href=edit_user.cgi>$text{'index_create'}</a>\n";
		$shown_users = 1;
		}
	}
elsif ($config{'display'}) {
	# Show as table of names
	print &ui_subheading($text{'index_users'});
	print &ui_form_start("delete_users.cgi", "post");
	&show_name_table(\@canulist, "edit_user.cgi",
			 $access{'create'} ? $text{'index_create'} : undef,
			 $text{'index_users'}, "user");
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	$shown_users = 1;
	$form++;
	}
else {
	# Show usernames and modules
	print &ui_subheading($text{'index_users'});
	@rowlinks = ( );
	if (!$config{'select'}) {
		print &ui_form_start("delete_users.cgi", "post");
		push(@rowlinks, &select_all_link("d", $form),
			     &select_invert_link("d", $form));
		}
	push(@rowlinks, "<a href=edit_user.cgi>$text{'index_create'}</a>")
		if ($access{'create'});
	print &ui_links_row(\@rowlinks);

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_user'}</b></td>\n";
	print "<td><b>$text{'index_modules'}</b></td> </tr>\n";
	foreach $u (@canulist) {
		print "<tr $cb>\n";
		print "<td valign=top>",
		      &user_link($u, "edit_user.cgi", "user"),"</td>\n";
		if ($ingroup{$u->{'name'}}) {
			# Is a member of a group
			&show_modules("user", $u->{'name'}, $u->{'ownmods'}, 0,
				      &text('index_modgroups',
					  "<tt>$ingroup{$u->{'name'}}->{'name'}</tt>"));
				      
			}
		else {
			# Is a stand-alone user
			&show_modules("user", $u->{'name'}, $u->{'modules'}, 1);
			}
		}
	print "</table>\n";
	print &ui_links_row(\@rowlinks);
	if (!$config{'select'}) {
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		}
	$shown_users = 1;
	$form++;
	}
print "<p>\n";

if ($shown_users && $access{'groups'}) {
	print "<hr>\n";
	}

if ($access{'groups'}) {
	print &ui_subheading($text{'index_groups'});
	if (!@glist) {
		# No groups, so just show create link
		print "<b>$text{'index_nogroups'}</b><p>\n";
		print "<a href=edit_group.cgi>$text{'index_gcreate'}</a><p>\n";
		}
	elsif ($config{'display'}) {
		print &ui_form_start("delete_groups.cgi", "post");
		&show_name_table(\@glist, "edit_group.cgi",
				 $text{'index_gcreate'},
				 $text{'index_group'}, "group");
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		$form++;
		}
	else {
		# Show table of groups
		@rowlinks = ( );
		if (!$config{'select'}) {
			print &ui_form_start("delete_groups.cgi", "post");
			push(@rowlinks, &select_all_link("d", $form),
				     &select_invert_link("d", $form));
			}
		push(@rowlinks,
		     "<a href=edit_group.cgi>$text{'index_gcreate'}</a>");
		print &ui_links_row(\@rowlinks);

		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'index_group'}</b></td>\n";
		print "<td><b>$text{'index_members'}</b></td>\n";
		print "<td><b>$text{'index_modules'}</b></td> </tr>\n";
		foreach $g (@glist) {
			print "<tr $cb> <td valign=top>\n";
			print &user_link($g,"edit_group.cgi","group"),"</td>\n";
			print "<td valign=top>",join(" ", @{$g->{'members'}}),
			      "&nbsp;</td>\n";

			if ($ingroup{'@'.$g->{'name'}}) {
				# Is a member of some other group
				&show_modules("group", $g->{'name'}, $g->{'ownmods'},0,
					&text('index_modgroups',
					  "<tt>$ingroup{$g->{'name'}}->{'name'}</tt>"));
				}
			else {
				# Is a top-level group
				&show_modules("group", $g->{'name'}, $g->{'modules'},1);
				}
			}
		print "</table>\n";
		print &ui_links_row(\@rowlinks);
		if (!$config{'select'}) {
			print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
			}
		$form++;
		}
	}

&get_miniserv_config(\%miniserv);
if ($access{'sync'} && &foreign_check("useradmin")) {
	push(@icons, "images/convert.gif");
	push(@links, "convert_form.cgi");
	push(@titles, $text{'index_convert'});
	}
if ($access{'sync'} && $access{'create'} && $access{'delete'}) {
	push(@icons, "images/sync.gif");
	push(@links, "edit_sync.cgi");
	push(@titles, $text{'index_sync'});
	}
if ($access{'unix'} && $access{'create'} && $access{'delete'}) {
	push(@icons, "images/unix.gif");
	push(@links, "edit_unix.cgi");
	push(@titles, $text{'index_unix'});
	}
if ($access{'sessions'} && $miniserv{'session'}) {
	push(@icons, "images/sessions.gif");
	push(@links, "list_sessions.cgi");
	push(@titles, $text{'index_sessions'});
	}
if (uc($ENV{'HTTPS'}) eq "ON" && $miniserv{'ca'}) {
	push(@icons, "images/cert.gif");
	push(@links, "cert_form.cgi");
	push(@titles, $text{'index_cert'});
	}
if ($access{'rbacenable'}) {
	push(@icons, "images/rbac.gif");
	push(@links, "edit_rbac.cgi");
	push(@titles, $text{'index_rbac'});
	}

if (@icons) {
	print "<hr>\n";
	&icons_table(\@links, \@titles, \@icons, scalar(@links));
	}

&ui_print_footer("/", $text{'index'});

# show_modules(type, who, &mods, show-global, prefix)
sub show_modules
{
local ($type, $who, $mods, $global, $prefix) = @_;
if ($config{'select'}) {
	# Show as drop-down menu
	print "<form action=edit_acl.cgi>\n";
	print "<td nowrap>\n";
	print $prefix,"<br>\n" if ($prefix);
	if (@$mods) {
		print "<input type=hidden name=$type value='$who'>\n";
		if ($access{'acl'}) {
			print "<input type=submit value='$text{'index_edit'}'>\n";
			}
		print "<select name=mod>\n";
		print "<option value=''>$text{'index_global'}\n" if ($global);
		foreach $m (sort { $modname{$a} cmp $modname{$b} } @$mods) {
			if ($modname{$m}) {
				print "<option value=$m>$modname{$m}\n";
				}
			}
		print "</select>\n";
		}
	print "</td></form> </tr>\n";
	}
else {
	# Show as table
	print "<td>\n";
	print $prefix,"<br>\n" if ($prefix);
	print "<table width=100% cellpadding=1 cellspacing=1>\n";
	print "<tr> <td width=33%>\n";
	if ($access{'acl'}) {
		print "<a href='edit_acl.cgi?mod=&$type=",
		      &urlize($who),"'>$text{'index_global'}</a></td>";
		$done = 1;
		}
	foreach $m (sort { $modname{$a} cmp $modname{$b} } @$mods) {
		if ($modname{$m}) {
			if ($done%3 == 0) { print "<tr>\n"; }
			print "<td width=33%>";
			if ($mcan{$m} && $access{'acl'}) {
				print "<a href='edit_acl.cgi?mod=",
				      &urlize($m),"&$type=",&urlize($who),
				      "'>$modname{$m}</a>";
				}
			else {
				print $modname{$m};
				}
			print "</td>\n";
			if ($done%3 == 2) { print "<tr>\n"; }
			$done++;
			}
		}
	while($done++ % 3) { print "<td width=33%></td>\n"; }
	print "</table>\n";
	print "</td> </tr>\n";
	}
}

# show_name_table(&users|&groups, cgi, create-text, header-text, param)
sub show_name_table
{
# Show table of users, and maybe create links
local @rowlinks = ( &select_all_link("d", $form),
		    &select_invert_link("d", $form) );
push(@rowlinks, "<a href=$_[1]>$_[2]</a>") if ($_[2]);
print &ui_links_row(\@rowlinks);
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$_[3]</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

for($i=0; $i<@{$_[0]}; $i++) {
	print "<tr>\n" if ($i%4 == 0);
	print "<td width=25%>",&user_link($_[0]->[$i], $_[1], $_[4]),"</td>\n";
	print "</td>\n";
	print "</tr>\n" if ($i%4 == 3);
	}
if ($i%4) {
	while($i++%4) {
		print "<td width=25%></td>\n";
		}
	print "</tr>\n";
	}

print "</table></td> </tr></table>\n";
print &ui_links_row(\@rowlinks);
}

# user_link(user, cgi, param)
sub user_link
{
local $lck = $_[0]->{'pass'} =~ /^\!/ ? 1 : 0;
local $ro = $_[0]->{'readonly'};
return ($config{'select'} ? "" : &ui_checkbox("d", $_[0]->{'name'}, "", 0)).
       ($lck ? "<i>" : "").
       ($ro ? "<b>" : "").
       "<a href='$_[1]?$_[2]=".&urlize($_[0]->{'name'})."'>".
	$_[0]->{'name'}."</a>".
       ($ro ? "</b>" : "").
       ($lck ? "</i>" : "");
}

