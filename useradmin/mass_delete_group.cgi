#!/usr/local/bin/perl
# Delete multiple groups

require './user-lib.pl';
&ReadParse();
%glist = map { $_->{'group'}, $_ } &list_groups();
&error_setup($text{'gmass_err'});
foreach $name (split(/\0/, $in{'gd'})) {
	$group = $glist{$name};
	if ($group) {
		&can_edit_group(\%access, $group) ||
			&error(&text('gmass_egroup', $name));
		push(@dlist, $group);
		$delete_sys = $group if ($group->{'gid'} < 10 &&
		    (!$delete_sys || $user->{'gid'} < $delete_sys->{'gid'}));
		}
	}
@dlist || &error($text{'gmass_enone'});
$access{'gdelete'} || &error($text{'gdel_egroup'});

&ui_print_header(undef, $text{'gmass_title'}, "");

# Check for deletion of system group
if (!$config{'delete_root'} && $delete_sys) {
	print "<p> <b>",&text('gmass_eroot',
			      $delete_root->{'group'}),"</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

if ($in{'confirmed'}) {
	foreach $group (@dlist) {
		# Show group name
		print "<b>",&text('gmass_doing', $group->{'group'}),"</b><br>\n";
		print "<ul>\n";

		# Delete from other modules
		if ($in{'others'}) {
			print "$text{'gdel_other'}<br>\n";
			local $error_must_die = 1;
			eval { &other_modules("useradmin_delete_group", $group); };
			if ($@) {
				print &text('udel_failed', $@),"<p>\n";
				}
			else {
				print "$text{'gdel_done'}<p>\n";
				}
			}

		# Delete from group file
		&lock_user_files();
		print "$text{'gdel_group'}<br>\n";
		&set_group_envs($group, 'DELETE_GROUP');
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

		&delete_group($group);
		&unlock_user_files();
		&made_changes();
		print "$text{'gdel_done'}<p>\n";

		print "</ul>\n";
		}

	&webmin_log("delete", "group", $group->{'group'}, $group);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	foreach $group (@dlist) {
		# check if this is anyone's primary group
		foreach $u (&list_users()) {
			if ($u->{'gid'} == $group->{'gid'}) {
				print "<b>",&text('gmass_eprimary',
					$group->{'group'}, $u->{'user'}),
					"</b> <p>\n";
				&ui_print_footer("", $text{'index_return'});
				exit;
				}
			}
		}

	# Ask if the user is sure
	print &ui_confirmation_form("mass_delete_group.cgi",
		&text('gmass_sure', scalar(@dlist)),
		[ [ "confirmed", 1 ],
		  map { [ "gd", $_->{'group'} ] } @dlist ],
		[ [ undef, $text{'gdel_del'} ] ],
		&ui_checkbox("others", 1, $text{'gdel_dothers'},
			     $config{'default_other'}),
		);

	&ui_print_footer("", $text{'index_return'});
	}

