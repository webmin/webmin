#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing an existing group

require './cluster-useradmin-lib.pl';
&ReadParse();

@hosts = &list_useradmin_hosts();
@servers = &list_servers();
if ($in{'host'} ne '') {
	($host) = grep { $_->{'id'} == $in{'host'} } @hosts;
	local ($g) = grep { $_->{'group'} eq $in{'group'} } @{$host->{'groups'}};
	%ginfo = %$g;
	}
else {
	foreach $h (@hosts) {
		local ($g) = grep { $_->{'group'} eq $in{'group'} }
				  @{$h->{'groups'}};
		if ($g) {
			$host = $h;
			%ginfo = %$g;
			last;
			}
		}
	}
($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
$desc = &text('gedit_host', $serv->{'desc'} ?
		$serv->{'desc'} : $serv->{'host'});
&ui_print_header($desc, $text{'gedit_title'}, "");

print "<form action=\"save_group.cgi\" method=post>\n";
print "<input type=hidden name=group value=\"$in{'group'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'gedit_group'}</b></td>\n";
print "<td valign=top><font size=+1><i>$ginfo{'group'}</i></font></td>\n";

print "<td valign=top><b>$text{'gedit_gid'}</b></td>\n";
printf "<td><input type=radio name=gid_def value=1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $ginfo{'gid'};
printf "<input type=radio name=gid_def value=0> %s\n",
	$text{'gedit_set'};
print "<input name=gid size=10></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'pass'}</b></td>\n";
printf "<td><input type=radio name=passmode value=-1 checked> %s (%s)\n",
	$text{'uedit_leave'}, $ginfo{'pass'} ? $ginfo{'pass'}
					     : $text{'uedit_none'};
print "<input type=radio name=passmode value=0> $text{'none2'}<br>\n";
print "<input type=radio name=passmode value=1> $text{'encrypted'}\n";
print "<input name=encpass size=13><br>\n";
print "<input type=radio name=passmode value=2> $text{'clear'}\n";
print "<input name=pass size=15></td>\n";

print "<td valign=top><b>$text{'gedit_members'}</b></td> <td>\n";
printf "<input type=radio name=members_def value=0 checked> %s (%s)<br>\n",
	$text{'uedit_leave'}, $ginfo{'members'} ? $ginfo{'members'}
						: $text{'uedit_none'};
printf "<input type=radio name=members_def value=1> %s\n", $text{'gedit_add'};
print "<input name=membersadd size=20> ",
	&user_chooser_button("membersadd", 1),"<br>\n";
printf "<input type=radio name=members_def value=2> %s\n", $text{'gedit_del'};
print "<input name=membersdel size=20> ",
	&user_chooser_button("membersdel", 1),"</td> </tr>\n";

print "</table></td> </tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'onsave'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'chgid'}</b></td>\n";
print "<td><input type=radio name=chgid value=0 checked> $text{'no'}</td>\n";
print "<td><input type=radio name=chgid value=1> $text{'gedit_homedirs'}</td>\n";
print "<td><input type=radio name=chgid value=2> $text{'gedit_allfiles'}</td> </tr>\n";

print "<tr> <td><b>$text{'uedit_servs'}</b></td>\n";
print "<td><input type=radio name=servs value=1> $text{'uedit_mall'}</td>\n";
print "<td><input type=radio name=servs value=0 checked> $text{'uedit_mthis'}</td> </tr>\n";

print "<tr> <td><b>$text{'gedit_mothers'}</b></td>\n";
print "<td><input type=radio name=others value=1 checked> $text{'yes'}</td>\n";
print "<td><input type=radio name=others value=0> $text{'no'}</td> </tr>\n";

print "</table></td> </tr></table><p>\n";

print "<table width=100%>\n";
print "<tr> <td><input type=submit value=\"$text{'save'}\"></td>\n";

# Find the servers this group is on
foreach $h (@hosts) {
	local ($og) = grep { $_->{'group'} eq $in{'group'} } @{$h->{'groups'}};
	if ($og) {
		local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
		push(@icons, $gconfig{'webprefix'} ?
			($gconfig{'webprefix'}."/servers/images/".$s->{'type'}.".gif") :
			("../servers/images/".$s->{'type'}.".gif"));
		push(@links, "edit_host.cgi?id=$h->{'id'}");
		push(@titles, $s->{'desc'} ? $s->{'desc'} : $s->{'host'});
		}
	}
if (@icons < @hosts) {
	# Offer to create on all servers
	print "</form><form action=\"sync.cgi\">\n";
	print "<input type=hidden name=server value=-1>\n";
	print "<input type=hidden name=users_mode value=0>\n";
	print "<input type=hidden name=groups_mode value=2>\n";
	print "<input type=hidden name=gsel value='$ginfo{'group'}'>\n";
	print "<td align=middle><input type=submit ",
	      "value=\"$text{'uedit_sync'}\"></td>\n";
	}

print "</form><form action=\"delete_group.cgi\">\n";
print "<input type=hidden name=group value=\"$ginfo{'group'}\">\n";
print "<td align=right><input type=submit value=\"$text{'delete'}\"></td> </tr>\n";
print "</form></table><p>\n";

print &ui_hr();
print &ui_subheading($text{'uedit_hosts'});
if ($config{'table_mode'}) {
	# Show as table
	print &ui_columns_start([ $text{'index_thost'},
				  $text{'index_tdesc'},
				  $text{'index_ttype'} ]);
	foreach $h (@hosts) {
		local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
		next if (!$s);
		local ($type) = grep { $_->[0] eq $s->{'type'} }
					@servers::server_types;
		local ($link) = $config{'conf_host_links'} ?
			&ui_link("edit_host.cgi?id=$h->{'id'}",($s->{'host'} || &get_system_hostname())) :
			($s->{'host'} || &get_system_hostname());
		print &ui_columns_row([
			$link,
			$s->{'desc'},
			$type->[1],
			]);
		}
	print &ui_columns_end();
	}
else {
	# Show as icons
	&icons_table(\@links, \@titles, \@icons);
	}

&ui_print_footer("", $text{'index_return'});

