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
	local ($link) = $config{'conf_host_links'} ? "edit_host.cgi?id=$h->{'id'}" : "#";
	push(@titles, $s->{'desc'} ? $s->{'desc'}
				   : "$s->{'host'}:$s->{'port'}");
	push(@links, $link);
	push(@icons, $gconfig{'webprefix'} ?
		($gconfig{'webprefix'}."/servers/images/".$s->{'type'}.".gif") :
		("../servers/images/".$s->{'type'}.".gif"));
	push(@installed, @{$h->{'packages'}});
	$gothost{$h->{'id'}}++;
	}
if (@links) {
	if ($config{'table_mode'}) {
		# Show as table
		print &ui_columns_start([ $text{'index_thost'},
					  $text{'index_tdesc'},
					  $text{'index_tucount'},
					  $text{'index_tgcount'},
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
				scalar(@{$h->{'users'}}),
				scalar(@{$h->{'groups'}}),
				$type->[1],
				]);
			}
		print &ui_columns_end();
		}
	else {
		# Show as icons
		&icons_table(\@links, \@titles, \@icons);
		}
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
			$s->{'desc'} ? $s->{'desc'} : $s->{'host'},"</option>\n";
		}
	print "</select></td>\n";
	}
@groups = &servers::list_all_groups(\@servers);
if (@groups) {
	print "<td align=right><input type=submit name=gadd ",
	      "value='$text{'index_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}</option>\n";
		}
	print "</select></td>\n";
	}
print "</tr></table></form>\n";

if ($config{'conf_add_user'} == 0 &&
	$config{'conf_add_group'} == 0 &&
	$config{'conf_allow_refresh'} == 0 &&
	$config{'conf_allow_sync'} == 0 &&
	$config{'conf_find_user'} == 0 &&
	$config{'conf_find_group'} == 0) {
	# If we have configured EVERY possible 'host' action off, then don't show
	# the header/horizontal-rule/etc...
	@hosts = ();
	}

if (@hosts) {
	# Display search and add forms
	print &ui_hr();
	print &ui_subheading($text{'index_users'});

	print "<table width=100%>";
	if ($config{'conf_find_user'} == 1 ||
    	    $config{'conf_add_user'} == 1) {
		print "<tr>\n";
	}
	if ($config{'conf_find_user'} == 1) {
		print "<td>\n";
		print "<form action=search_user.cgi>\n";
		print "<b>$text{'index_finduser'}</b> <select name=field>\n";
		print "<option value=user checked>$text{'user'}</option>\n";
		print "<option value=real>$text{'real'}</option>\n";
		print "<option value=shell>$text{'shell'}</option>\n";
		print "<option value=home>$text{'home'}</option>\n";
		print "<option value=uid>$text{'uid'}</option>\n";
		print "</select> <select name=match>\n";
		print "<option value=0 checked>$text{'index_equals'}";
		print "</option>\n";
		print "<option value=4>$text{'index_contains'}</option>\n";
		print "<option value=1>$text{'index_matches'}</option>\n";
		print "<option value=5>$text{'index_ncontains'}</option>\n";
		print "<option value=3>$text{'index_nmatches'}</option>\n";
		print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
		print "<input type=submit value=\"$text{'find'}\"></form>\n";
		print "</td>\n";
	}

	if ($config{'conf_add_user'} == 1 &&
    	    $config{'conf_find_user'} == 1) {
		print "<td align=right>\n";
	}
	elsif ($config{'conf_add_user'} == 1) {
		print "<td>\n";
	}
	if ($config{'conf_add_user'} == 1) {
		print "<form action=user_form.cgi>\n";
		print "<input type=hidden name=new value=1>\n";
		print "<input type=submit value='$text{'index_newuser'}'>\n";
		print "</form>\n";
		print "</td>\n";
	}
	if ($config{'conf_find_user'} == 1 ||
    	    $config{'conf_add_user'} == 1) {
		print "</tr>\n";
	}

	if ($config{'conf_find_group'} == 1 ||
    	    $config{'conf_add_group'} == 1) {
		print "<tr>\n";
	}
	if ($config{'conf_find_group'} == 1) {
		print "<td>\n";
		print "<form action=search_group.cgi>";
		print "<b>$text{'index_findgroup'}</b> <select name=field>\n";
		print "<option value=group checked>$text{'gedit_group'}";
		print "</option>\n";
		print "<option value=members>$text{'gedit_members'}";
		print "</option>\n";
		print "<option value=gid>$text{'gedit_gid'}</option>\n";
		print "</select> <select name=match>\n";
		print "<option value=0 checked>$text{'index_equals'}";
		print "</option>\n";
		print "<option value=4>$text{'index_contains'}</option>\n";
		print "<option value=1>$text{'index_matches'}</option>\n";
		print "<option value=5>$text{'index_ncontains'}</option>\n";
		print "<option value=3>$text{'index_nmatches'}</option>\n";
		print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
		print "<input type=submit value=\"$text{'find'}\">";
		print "</form>\n";
		print "</td>";
	}

	if ($config{'conf_add_group'} == 1 &&
    	    $config{'conf_find_group'} == 1) {
		print "<td align=right>\n";
	}
	elsif ($config{'conf_add_group'} == 1) {
		print "<td>\n";
	}
	if ($config{'conf_add_group'} == 1) {
		print "<form action=group_form.cgi>\n";
		print "<input type=hidden name=new value=1>\n";
		print "<input type=submit value='$text{'index_newgroup'}'>\n";
		print "</form></td>\n";
	}
	if ($config{'conf_find_group'} == 1 ||
    	    $config{'conf_add_group'} == 1) {
		print "</tr>\n";
	}

	if ($config{'conf_allow_refresh'} == 1 ||
    	    $config{'conf_allow_sync'} == 1) {
		print "<tr>\n";
	}
	if ($config{'conf_allow_refresh'} == 1) {
		print "<td>\n";
		print "<form action=refresh.cgi>\n";
		print "<input type=submit value='$text{'index_refresh'}'>\n";
		&create_on_input(undef, 1);
		print "</form>\n";
		print "</td>\n";
	}

	if ($config{'conf_allow_refresh'} == 1 &&
    	    $config{'conf_allow_sync'} == 1) {
		print "<td align=right>";
	}
	else {
		print "<td>";
	}
	if ($config{'conf_allow_sync'} == 1) {
		print "<form action=sync_form.cgi>\n";
		print "<input type=submit value='$text{'index_sync'}'>\n";
		print "</form>\n";
		print "</td>\n";
	}
	if ($config{'conf_allow_refresh'} == 1 ||
    	    $config{'conf_allow_sync'} == 1) {
		print "</tr>\n";
	}
	print "</table>\n";
}

&ui_print_footer("/", $text{'index'});
