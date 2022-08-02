#!/usr/local/bin/perl
# Shows hosts on which Usermin is installed

require './cluster-usermin-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Display hosts on which modules will be installed
print &ui_subheading($text{'index_hosts'});
@servers = &list_servers();
@hosts = &list_usermin_hosts();
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
	push(@icons, "@{[&get_webprefix()]}/servers/images/$s->{'type'}.svg");
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

# Show button for adding server
print "<table data-post-icon-row-submit width=100%><tr>\n";
@addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers) {
	print "<td><form action=add.cgi>\n";
	print "<input type=submit name=add value='$text{'index_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (@addservers) {
		print "<option value=$s->{'id'}>",&server_name($s),"</option>\n";
		}
	print "</select>\n";
	print "</td></form>\n";
	$formno++;
	}
else { print "<td></td>\n"; }

# Show button for adding server group
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
	# Display modules lists and new module form
	print &ui_hr();
	print &ui_subheading($text{'index_modules'});
	print "<table width=100%><tr>\n";
	print "<td><form action=edit_mod.cgi>\n";
	print "<input type=submit value=\"$text{'index_edit'}\">\n";
	print $modsel;
	print "<input type=submit name=tedit value=\"$text{'index_tedit'}\">\n";
	print $themesel;
	print "</form></td></tr>\n";
	$formno++;

	print "<tr> <td align=left colspan=2><form action=refresh.cgi>\n";
	print "<input type=submit value='$text{'index_refresh'}'>\n";
	&create_on_input(undef, 1, 1);
	print "</form></td>\n";
	$formno++;
	print "</table><p>\n";

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

	print "<input type=checkbox name=nodeps value=1> ",
	      "$text{'index_nodeps'}<br>\n";

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
	$mode = &usermin::get_install_type();

	print "<form action=upgrade.cgi method=post enctype=multipart/form-data>\n";
	print "<input type=hidden name=mode value='$mode'>\n";

	print "<input type=radio name=source value=0> $text{'index_local'}\n";
	print "<input name=file size=40>\n";
	print &file_chooser_button("file", 0, $formno),"<br>\n";
	print "<input type=radio name=source value=1> $text{'index_uploaded'}\n";
	print "<input name=upload type=file size=30><br>\n";
	print "<input type=radio name=source value=5> $text{'index_ftp'}\n";
	print "<input name=url size=40><br>\n";
	if ($in{'mode'} eq 'rpm' || !$in{'mode'}) {
		print "<input type=radio name=source value=2 checked> $webmin::text{'upgrade_ftp'}<br>\n";
		}
	print "<p>\n";

	print "<input type=checkbox name=delete value=1> ",
		"$webmin::text{'upgrade_delete'}<br>\n";
	print "$text{'index_upgradeon'}\n";
	&create_on_input();
	print "<input type=submit value=\"$usermin::text{'upgrade_ok'}\">\n";
	print "</form>\n";
	$formno++;
	}

&ui_print_footer("/", $text{'index'});

