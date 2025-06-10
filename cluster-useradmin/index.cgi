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
	push(@titles, &server_name($s));
	push(@links, $link);
	push(@icons, &get_webprefix()."/servers/images/".
		     $s->{'type'}.".svg");
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
				&ui_link("edit_host.cgi?id=$h->{'id'}",
				  ($s->{'host'} || &get_system_hostname())) :
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

print &ui_buttons_start();

# Add one server
my @addservers = grep { !$gothost{$_->{'id'}} } @servers;
if (@addservers) {
	print &ui_buttons_row("add.cgi", $text{'index_add'}, undef,
			      [ [ "add", 1 ] ],
			      &ui_select("server", undef,
				[ map { [ $_->{'id'}, &server_name($_) ] }
				      @addservers ]));
	}

# Add one group
@groups = &servers::list_all_groups(\@servers);
if (@groups) {
	print &ui_buttons_row("add.cgi", $text{'index_gadd'}, undef,
			      [ [ "gadd", 1 ] ],
			      &ui_select("group", undef,
				[ map { $_->{'name'} } @groups ]));
	}

print &ui_buttons_end();

if (!$config{'conf_add_user'} &&
    !$config{'conf_add_group'} &&
    !$config{'conf_allow_refresh'} &&
    !$config{'conf_allow_sync'} &&
    !$config{'conf_find_user'} &&
    !$config{'conf_find_group'}) {
	# If we have configured EVERY possible 'host' action off, then don't
	# show the header/horizontal-rule/etc...
	@hosts = ();
	}

if (@hosts) {
	# Display search and add forms
	print &ui_hr();
	print &ui_subheading($text{'index_users'});

	print &ui_buttons_start();

	if ($config{'conf_find_user'}) {
		print &ui_buttons_row(
			"search_user.cgi",
			$text{'index_finduser'},
			undef,
			undef,
			&ui_select("field", "user",
				[ [ "user", $text{'user'} ],
				  [ "real", $text{'real'} ],
				  [ "shell", $text{'shell'} ],
				  [ "home", $text{'home'} ],
				  [ "uid", $text{'uid'} ] ])." ".
			&ui_select("match", 0,
				   [ [ 0, $text{'index_equals'} ],
				     [ 4, $text{'index_contains'} ],
				     [ 1, $text{'index_matches'} ],
				     [ 5, $text{'index_ncontains'} ],
				     [ 3, $text{'index_nmatches'} ] ])." ".
			&ui_textbox("what", undef, 15));
		}

	if ($config{'conf_find_group'}) {
		print &ui_buttons_row(
			"search_group.cgi",
			$text{'index_findgroup'},
			undef,
			undef,
			&ui_select("field", "group",
				[ [ "group", $text{'gedit_group'} ],
				  [ "members", $text{'gedit_members'} ],
				  [ "gid", $text{'gid'} ] ])." ".
			&ui_select("match", 0,
				   [ [ 0, $text{'index_equals'} ],
				     [ 4, $text{'index_contains'} ],
				     [ 1, $text{'index_matches'} ],
				     [ 5, $text{'index_ncontains'} ],
				     [ 3, $text{'index_nmatches'} ] ])." ".
			&ui_textbox("what", undef, 15));
		}

	print &ui_buttons_hr();

	if ($config{'conf_add_user'}) {
		print &ui_buttons_row("user_form.cgi",
				      $text{'index_newuser'},
				      undef,
				      [ [ "new", 1 ] ]);
		}

	if ($config{'conf_add_group'}) {
		print &ui_buttons_row("group_form.cgi",
				      $text{'index_newgroup'},
				      undef,
				      [ [ "new", 1 ] ]);
		}

	print &ui_buttons_hr();

	if ($config{'conf_allow_refresh'}) {
		print &ui_buttons_row("refresh.cgi",
				      $text{'index_refresh'}, undef, undef,
				      &create_on_input(1));
		}

	if ($config{'conf_allow_sync'}) {
		print &ui_buttons_row("sync_form.cgi", $text{'index_sync'});
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
