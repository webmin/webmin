#!/usr/local/bin/perl
# index.cgi
# Display hosts on which users are being managed, and inputs for adding more

require './cluster-useradmin-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Display hosts on which users will be managed
print &ui_subheading($text{'index_hosts'});
@servers = &list_servers();
@hosts = &list_useradmin_hosts();
if ($config{'sort_mode'} == 1) {
	@hosts = sort { my ($as) = grep { $_->{'id'} == $a->{'id'} } @servers;
			my ($bs) = grep { $_->{'id'} == $b->{'id'} } @servers;
			lc($as->{'host'}) cmp lc($bs->{'host'}) } @hosts;
	}
elsif ($config{'sort_mode'} == 2) {
	@hosts = sort { my ($as) = grep { $_->{'id'} == $a->{'id'} } @servers;
			my ($bs) = grep { $_->{'id'} == $b->{'id'} } @servers;
			lc(&server_name($as)) cmp lc(&server_name($bs)) }@hosts;
	}
$formno = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	next if (!$s);
	push(@titles, $s->{'desc'} ? $s->{'desc'}
				   : "$s->{'host'}:$s->{'port'}");
	push(@links, "edit_host.cgi?id=$h->{'id'}");
	push(@icons, "$gconfig{'webprefix'}/servers/images/$s->{'type'}.gif");
	push(@installed, @{$h->{'packages'}});
	$gothost{$h->{'id'}}++;
	}
if (@links) {
	&icons_table(\@links, \@titles, \@icons);
	}
else {
	print "<b>$text{'index_nohosts'}</b><p>\n";
	}
$formno++;
print "<form action=add.cgi>\n";
print "<table width=100%><tr>\n";
@addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers) {
	print "<td><input type=submit name=add value='$text{'index_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (@addservers) {
		print "<option value=$s->{'id'}>",
			$s->{'desc'} ? $s->{'desc'} : $s->{'host'},"\n";
		}
	print "</select></td>\n";
	}
@groups = &servers::list_all_groups(\@servers);
if (@groups) {
	print "<td align=right><input type=submit name=gadd ",
	      "value='$text{'index_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}\n";
		}
	print "</select></td>\n";
	}
print "</tr></table></form>\n";

if (@hosts) {
	# Display search and add forms
	print "<hr>\n";
	print &ui_subheading($text{'index_users'});

	print "<table width=100%><tr>\n";
	print "<form action=search_user.cgi><td>\n";
	print "<b>$text{'index_finduser'}</b> <select name=field>\n";
	print "<option value=user checked>$text{'user'}\n";
	print "<option value=real>$text{'real'}\n";
	print "<option value=shell>$text{'shell'}\n";
	print "<option value=home>$text{'home'}\n";
	print "<option value=uid>$text{'uid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></td></form>\n";

	print "<form action=user_form.cgi><td align=right>\n";
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value='$text{'index_newuser'}'>\n";
	print "</td></form></tr>\n";

	print "<tr><form action=search_group.cgi><td>\n";
	print "<b>$text{'index_findgroup'}</b> <select name=field>\n";
	print "<option value=group checked>$text{'gedit_group'}\n";
	print "<option value=members>$text{'gedit_members'}\n";
	print "<option value=gid>$text{'gedit_gid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=4>$text{'index_contains'}\n";
	print "<option value=1>$text{'index_matches'}\n";
	print "<option value=5>$text{'index_ncontains'}\n";
	print "<option value=3>$text{'index_nmatches'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></td></form>\n";

	print "<form action=group_form.cgi><td align=right>\n";
	print "<input type=hidden name=new value=1>\n";
	print "<input type=submit value='$text{'index_newgroup'}'>\n";
	print "</td></form></tr>\n";

	print "<tr><form action=refresh.cgi>\n";
	print "<td><input type=submit value='$text{'index_refresh'}'>\n";
	&create_on_input(undef, 1);
	print "</td>\n";
	print "</form>\n";

	print "<form action=sync_form.cgi>\n";
	print "<td align=right><input type=submit ",
	      "value='$text{'index_sync'}'></td>\n";
	print "</form></tr> </table>\n";
	}

&ui_print_footer("/", $text{'index'});

