#!/usr/local/bin/perl
# index.cgi
# Display hosts on which software packages are being managed, a form for
# finding existing packages and a form for installing more

require './cluster-software-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Display hosts on which software will be installed
print &ui_subheading($text{'index_hosts'});
@servers = &list_servers();
@hosts = &list_software_hosts();
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
	local $count = @{$h->{'packages'}};
	push(@titles, ($s->{'desc'} ? $s->{'desc'} :
		       $s->{'realhost'} ? "$s->{'realhost'}:$s->{'port'}" :
				     "$s->{'host'}:$s->{'port'}")."<br>".
		      &text('index_count', $count));
	push(@links, "edit_host.cgi?id=$h->{'id'}");
	push(@icons, "$gconfig{'webprefix'}/servers/images/$s->{'type'}.gif");
	push(@installed, $count);
	$gothost{$h->{'id'}}++;
	}
if (@links) {
	if ($config{'table_mode'}) {
		# Show as table
		print &ui_columns_start([ $text{'index_thost'},
					  $text{'index_tdesc'},
					  $text{'index_tcount'},
					  $text{'index_ttype'} ]);
		foreach $h (@hosts) {
			local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
			next if (!$s);
			local ($type) = grep { $_->[0] eq $s->{'type'} }
					     @servers::server_types;
			print &ui_columns_row([
				&ui_link("edit_host.cgi?id=$h->{'id'}",($s->{'host'} || &get_system_hostname())),
				$s->{'desc'},
				scalar(@{$h->{'packages'}}),
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

# Show form for adding a server
print "<table width=100%><tr>\n";
@addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers && $access{'add'}) {
	print "<td width=33%><form action=add.cgi>\n";
	print "<input type=submit name=add value='$text{'index_add'}'>\n";
	print "<select name=server>\n";
	foreach $s (sort { $a->{'host'} cmp $b->{'host'} } @addservers) {
		print "<option value=$s->{'id'}>",
		    $s->{'host'}.($s->{'desc'} ? " ($s->{'desc'})" : ""),"</option>\n";
		}
	print "</select>\n";
	print "</form></td>\n";
	}

# Show button for compare form
if (@hosts) {
	print "<form action=compare_form.cgi>\n";
	print "<td align=center width=33%>\n";
	print "<input type=submit value='$text{'index_compare'}'>\n";
	print "</td>\n";
	print "</form>\n";
	}

# Show form for adding a group of servers
@groups = &servers::list_all_groups(\@servers);
if (@groups && $access{'add'}) {
	print "<td align=right width=33%><form action=add.cgi>\n";
	print "<input type=submit name=gadd value='$text{'index_gadd'}'>\n";
	print "<select name=group>\n";
	foreach $g (@groups) {
		print "<option>$g->{'name'}</option>\n";
		}
	print "</select>\n";
	print "</form></td>\n";
	}
print "</tr></table>\n";

if (@hosts) {
	# Display search form
	print &ui_hr();
	print &ui_subheading($text{'index_installed'});
	print "<table cellpadding=0 cellspacing=0 width=100%><tr><td>\n";
	$formno += 2;
	print "<form action=search.cgi>\n";
	print "<input type=submit value=\"$text{'index_search'}\">\n";
	print "<input name=search size=30>\n";
	print "</form></td>\n";

	print "<td align=right><form action=refresh.cgi>\n";
	print "<input type=submit value=\"$text{'index_refresh'}\">\n";
	&create_on_input(undef, 1, 1);
	print "</form></td> </tr></table>\n";

	# Display cross-cluster install form
	print &ui_hr();
	print &ui_subheading($text{'index_install'});
	print "$text{'index_installmsg'}<p>\n";

	$upid = time().$$;
	print &ui_form_start("install_pack.cgi?id=$upid", "form-data", undef,
		     &read_parse_mime_javascript($upid, [ "upload" ])),"\n";

	@opts = ( );
	push(@opts, [ 0, $text{'index_local'},
		      &ui_textbox("local", undef, 50)."\n".
		      &file_chooser_button("local", 0, 2) ]);
	push(@opts, [ 1, $text{'index_uploaded'},
		      &ui_upload("upload", 50) ]);
	push(@opts, [ 2, $text{'index_ftp'},
		      &ui_textbox("url", undef, 50)."<br>\n".
		      &ui_checkbox("down", 1, $text{'index_down'}, 0) ]);
	if ($software::has_update_system) {
		push(@opts, [ 3,
		      $software::text{$software::update_system.'_input'},
		      &ui_textbox("update", undef, 30)."\n".
		      &software::update_system_button("update",
			    $software::text{$software::update_system.'_find'})
		      ]);
		}
	print &ui_radio_table("source", 0, \@opts);
	print &ui_submit($text{'index_installok'}),"\n";
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

