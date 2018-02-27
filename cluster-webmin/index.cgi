#!/usr/local/bin/perl
# index.cgi
# Display hosts on which webmin modules are being managed, a list of
# installed modules and a form for installing new ones

require './cluster-webmin-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Display hosts on which modules will be installed
print &ui_subheading($text{'index_hosts'});
@servers = &list_servers();
@hosts = &list_webmin_hosts();
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
	push(@titles, &server_name($s)."<br>".
		      &text('index_version', $h->{'version'}));
	push(@links, "edit_host.cgi?id=$h->{'id'}");
	push(@icons, "$gconfig{'webprefix'}/servers/images/$s->{'type'}.gif");
	$gothost{$h->{'id'}}++;
	}
if (@links) {
	if ($config{'table_mode'}) {
		# Show as table
		print &ui_columns_start([ $text{'index_thost'},
					  $text{'index_tdesc'},
					  $text{'index_tver'},
					  $text{'index_ttype'} ]);
		foreach $h (@hosts) {
			local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
			next if (!$s);
			local ($type) = grep { $_->[0] eq $s->{'type'} }
					     @servers::server_types;
			print &ui_columns_row([
				&ui_link("edit_host.cgi?id=$h->{'id'}",($s->{'host'} || &get_system_hostname())),
				$s->{'desc'},
				$h->{'version'},
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
	# Nothing to show
	print "<b>$text{'index_nohosts'}</b><p>\n";
	}

# Build common selectors
@wgroups = &all_groups(\@hosts);
$modsel2 = $modsel = "<select name=mod>\n";
$modsel2 .= "<option value=''>$text{'index_gacl'}</option>\n";
foreach $m (&all_modules(\@hosts)) {
	$modsel .= "<option value=$m->{'dir'}>$m->{'desc'}</option>\n";
	$modsel2 .= "<option value=$m->{'dir'}>$m->{'desc'}</option>\n";
	}
$modsel .= "</select>\n";
$modsel2 .= "</select>\n";
$themesel = "<select name=theme>\n";
foreach $t (&all_themes(\@hosts)) {
	$themesel .= "<option value=$t->{'dir'}>$t->{'desc'}</option>\n";
	}
$themesel .= "</select>\n";
$usersel = "<select name=user>\n";
foreach $u (&all_users(\@hosts)) {
	$usersel .= "<option>$u->{'name'}</option>\n";
	}
$usersel .= "</select>\n";
$groupsel = "<select name=group>\n";
foreach $u (@wgroups) {
	$groupsel .= "<option>$u->{'name'}</option>\n";
	}
$groupsel .= "</select>\n";

print "<table width=100%><tr>\n";
@addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers) {
	print "<td><form action=add.cgi>\n";
	print "<input type=submit name=add value='$text{'index_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (sort { $a->{'host'} cmp $b->{'host'} } @addservers) {
		print "<option value=$s->{'id'}>",&server_name($s),"</option>\n";
		}
	print "</select>\n";
	print "</form></td>\n";
	$formno++;
	}
else { print "<td></td>\n"; }

@groups = &servers::list_all_groups(\@servers);
if (@groups) {
	print "<td align=right><form action=add.cgi>\n";
	print "<input type=submit name=gadd value='$text{'index_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}</option>\n";
		}
	print "</select>\n";
	print "</form></td>\n";
	$formno++;
	}
else { print "<td></td>\n"; }
print "</tr></table>\n";

if (@hosts) {
	# Display user search forms and new user buttons
	print &ui_hr();
	print &ui_subheading($text{'index_users'});
	print "<table width=100%>\n";

	print "<tr><form action=edit_user.cgi><td>\n";
	print "<input type=submit value='$text{'index_euser'}'>\n";
	print $usersel;
	print "</td></form>\n";
	$formno++;

	print "<form action=edit_acl.cgi><td>\n";
	print "<input type=submit value='$text{'index_euseracl'}'>\n";
	print $usersel;
	print "$text{'index_inmod'}\n";
	print $modsel2;
	print "</td></form>\n";
	$formno++;

	print "<form action=user_form.cgi><td align=right>\n";
	print "<input type=submit value='$text{'index_cuser'}'>\n";
	print "</td></form></tr>\n";
	$formno++;

	if (@wgroups) {
		print "<tr><form action=edit_group.cgi><td>\n";
		print "<input type=submit value='$text{'index_egroup'}'>\n";
		print $groupsel;
		print "</td></form>\n";
		$formno++;

		print "<form action=edit_acl.cgi><td>\n";
		print "<input type=submit value='$text{'index_egroupacl'}'>\n";
		print $groupsel;
		print "$text{'index_inmod'}\n";
		print $modsel2;
		print "</td></form>\n";
		$formno++;
		}
	else {
		print "<tr> <td colspan=2></td>\n";
		}

	print "<form action=group_form.cgi><td align=right>\n";
	print "<input type=submit value='$text{'index_cgroup'}'>\n";
	print "</td></form></tr>\n";
	$formno++;

	print "<tr> <form action=refresh.cgi><td align=left colspan=2>\n";
	print "<input type=submit value='$text{'index_refresh'}'>\n";
	&create_on_input(undef, 1, 1);
	print "</td></form>\n";
	$formno++;

	print "<form action=sync_form.cgi><td align=right>\n";
	print "<input type=submit value='$text{'index_sync'}'>\n";
	print "</td></form></tr>\n";
	$formno++;

	print "</table>\n";

	# Display modules lists and new module form
	print &ui_hr();
	print &ui_subheading($text{'index_modules'});
	print "<table width=100%><tr>\n";
	print "<td><form action=edit_mod.cgi>\n";
	print "<input type=submit value=\"$text{'index_edit'}\">\n";
	print $modsel;
	print "</form></td>\n";

	print "<td align=right><form action=edit_mod.cgi>\n";
	print "<input type=submit name=tedit value=\"$text{'index_tedit'}\">\n";
	print $themesel;
	print "</form></td>\n";
	print "</tr></table><p>\n";
	$formno++;

	print "<form action=install.cgi method=post ",
	      "enctype=multipart/form-data>\n";
	print "$text{'index_installmsg'}<p>\n";
	print "<input type=radio name=source value=0 checked> $text{'index_local'}\n";
	print "<input name=local size=50>\n";
	print &file_chooser_button("local", 0, $formno); print "<br>\n";
	print "<input type=radio name=source value=1> $text{'index_uploaded'}\n";
	print "<input type=file name=upload size=20><br>\n";
	print "<input type=radio name=source value=2> $text{'index_ftp'}\n";
	print "<input name=url size=50><br>\n";
	print "&nbsp;" x 5,"<input type=checkbox name=down value=1> ",
	      "$text{'index_down'}<p>\n";

	print "<input type=radio name=grant value=0 checked> ",
	      "$text{'index_grant2'}\n";
	print "<input name=grantto size=30 value='$base_remote_user'><br>\n";
	print "<input type=radio name=grant value=1> ",
	      "$text{'index_grant1'}<br>\n";

	print "<input type=checkbox name=nodeps value=1> ",
	      "$text{'index_nodeps'}<p>\n";

	print "$text{'index_installon'}\n";
	&create_on_input();
	print "<p>\n";

	print "<input type=submit value=\"$text{'index_installok'}\">\n";
	print "</form>\n";
	$formno++;

	# Display upgrade form
	&foreign_require("webmin", "webmin-lib.pl");
	print &ui_hr();
	print &ui_subheading($text{'index_upgrade'});
	print "$text{'index_updesc'}<p>\n";

	# what kind of install is the local system?
	$mode = &webmin::get_install_type();

	print "<form action=upgrade.cgi method=post enctype=multipart/form-data>\n";
	print "<input type=hidden name=mode value='$mode'>\n";

	print "<input type=radio name=source value=0> $text{'index_local'}\n";
	print "<input name=file size=40>\n";
	print &file_chooser_button("file", 0, $formno),"<br>\n";
	print "<input type=radio name=source value=1> $text{'index_uploaded'}\n";
	print "<input name=upload type=file size=30><br>\n";
	print "<input type=radio name=source value=5> $text{'index_ftp'}\n";
	print "<input name=url size=40><br>\n";
	if ($in{'mode'} eq 'rpm' || $mode eq 'deb' || !$in{'mode'}) {
		print "<input type=radio name=source value=2 checked> $webmin::text{'upgrade_ftp'}<br>\n";
		}
	print "<p>\n";

	printf "<input type=checkbox name=sig value=1> %s<br>\n",
		$webmin::text{'upgrade_sig'};
	print "<input type=checkbox name=delete value=1> ",
		"$webmin::text{'upgrade_delete'}<br>\n";
	print "<input type=checkbox name=only value=1> ",
		"$webmin::text{'upgrade_only'}<br>\n";
	print "$text{'index_upgradeon'}\n";
	&create_on_input();
	print "<input type=submit value=\"$webmin::text{'upgrade_ok'}\">\n";
	print "</form>\n";
	$formno++;

	# Show form for installing updates
	print &ui_hr();
	print &ui_subheading($text{'index_update'});
	print "$text{'index_updatedesc'}<p>\n";
	print "<form action=update.cgi>\n";

	printf "<input type=radio name=source value=0 %s> %s<br>\n",
		$webmin::config{'upsource'} ? "" : "checked",
		$webmin::text{'update_webmin'};
	printf "<input type=radio name=source value=1 %s> %s\n",
		$webmin::config{'upsource'} ? "checked" : "",
		$webmin::text{'update_other'};
	printf "<input name=other size=30 value='%s'><p>\n",
		$webmin::config{'upsource'};

	printf "<input type=checkbox name=show value=1 %s> %s<br>\n",
		$webmin::config{'upshow'} ? "checked" : "",
		$webmin::text{'update_show'};
	printf "<input type=checkbox name=missing value=1 %s> %s<br>\n",
		$webmin::config{'upmissing'} ? "checked" : "",
		$webmin::text{'update_missing'};
	printf "<input type=checkbox name=third value=1 %s> %s<br>\n",
		$webmin::config{'upthird'} ? "checked" : "",
		$webmin::text{'update_third'};

	print "$text{'index_updateon'}\n";
	&create_on_input(undef, 1);

	print "<input type=submit value=\"$webmin::text{'update_ok'}\">\n";
	print "</form>\n";
	}

&ui_print_footer("/", $text{'index'});

