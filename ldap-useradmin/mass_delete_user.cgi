#!/usr/local/bin/perl
# mass_delete_user.cgi
# Delete multiple users, after asking for confirmation

require './ldap-useradmin-lib.pl';
&ReadParse();
$ldap = &ldap_connect();
%ulist = map { $_->{'user'}, $_ } &list_users();
&error_setup($text{'umass_err'});
foreach $name (split(/\0/, $in{'d'})) {
	$user = $ulist{$name};
	if ($user) {
		&can_edit_user($user) ||
			&error(&text('umass_euser', $name));
		push(@dlist, $user);
		$delete_sys = $user if ($user->{'uid'} < 10 &&
		    (!$delete_sys || $user->{'uid'} < $delete_sys->{'uid'}));
		}
	}
@dlist || &error($text{'umass_enone'});

if ($in{'disable'}) {
	# Disabling a bunch of users
	&ui_print_unbuffered_header(undef, $text{'dmass_title'}, "");

	if ($in{'confirmed'}) {
		foreach $user (@dlist) {
			# Show username
			print "<b>",&text('dmass_doing', $user->{'user'}),"</b><br>\n";
			print "<ul>\n";

			# Run the before command
			local @secs;
			foreach $g (&list_groups()) {
				@mems = split(/,/, $g->{'members'});
				if (&indexof($user->{'user'}, @mems) >= 0) {
					push(@secs, $g->{'gid'});
					}
				}
			&set_user_envs($user, 'MODIFY_USER', undef, \@secs);
			$merr = &making_changes();
			&error(&text('usave_emaking', "<tt>$merr</tt>"))
				if (defined($merr));

			# Do it
			&lock_user_files();
			print "$text{'dmass_pass'}<br>\n";
			if ($user->{'pass'} !~ /^$useradmin::disable_string/) {
				$user->{'pass'} =
				    $useradmin::disable_string.$user->{'pass'};
				&modify_user($user, $user);
				print "$text{'udel_done'}<p>\n";
				}
			else {
				print "$text{'dmass_already'}<p>\n";
				}
			&unlock_user_files();

			&made_changes();
			print "</ul>\n";
			}

		&webmin_log("disable", "users", scalar(@dlist),
			    { 'user' => [ map { $_->{'user'} } @dlist ] });

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		# Ask if the user is sure
		print &ui_confirmation_form(
			"mass_delete_user.cgi",
			&text('dmass_sure', scalar(@dlist)),
			[ [ "confirmed", 1 ],
			  [ "disable", 1 ],
			  map { [ "d", $_->{'user'} ] } @dlist ],
			[ [ undef, $text{'dmass_dis'} ] ],
			);

		&ui_print_footer("", $text{'index_return'});
		}
	}
elsif ($in{'enable'}) {
	# Enabling a bunch of users
	&ui_print_unbuffered_header(undef, $text{'emass_title'}, "");

	foreach $user (@dlist) {
		# Show username
		print "<b>",&text('emass_doing', $user->{'user'}),"</b><br>\n";
		print "<ul>\n";

		# Run the before command
		local @secs;
		foreach $g (&list_groups()) {
			@mems = split(/,/, $g->{'members'});
			if (&indexof($user->{'user'}, @mems) >= 0) {
				push(@secs, $g->{'gid'});
				}
			}
		&set_user_envs($user, 'MODIFY_USER', undef, \@secs);
		$merr = &making_changes();
		&error(&text('usave_emaking', "<tt>$merr</tt>"))
			if (defined($merr));

		# Do it
		&lock_user_files();
		print "$text{'emass_pass'}<br>\n";
		if ($user->{'pass'} =~ s/^$useradmin::disable_string//) {
			&modify_user($user, $user);
			print "$text{'udel_done'}<p>\n";
			}
		else {
			print "$text{'emass_already'}<p>\n";
			}
		&unlock_user_files();

		&made_changes();
		print "</ul>\n";
		}

	&webmin_log("enable", "users", scalar(@dlist),
		    { 'user' => [ map { $_->{'user'} } @dlist ] });

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Deleting a bunch of users
	&ui_print_unbuffered_header(undef, $text{'umass_title'}, "");

	if ($in{'confirmed'}) {
		foreach $user (@dlist) {
			# Show username
			print "<b>",&text('umass_doing', $user->{'user'}),"</b><br>\n";
			print "<ul>\n";

			# Run the before command
			local @secs;
			foreach $g (&list_groups()) {
				@mems = split(/,/, $g->{'members'});
				if (&indexof($user->{'user'}, @mems) >= 0) {
					push(@secs, $g->{'gid'});
					}
				}
			&set_user_envs($user, 'DELETE_USER', undef, \@secs);
			$merr = &making_changes();
			&error(&text('usave_emaking', "<tt>$merr</tt>"))
				if (defined($merr));

			# Go ahead and do it!
			if ($mconfig{'default_other'}) {
				print "$text{'udel_other'}<br>\n";
				local $error_must_die = 1;
				eval { &other_modules("useradmin_delete_user",$user); };
				if ($@) {
					print &text('udel_failed', $@),"<p>\n";
					}
				else {
					print "$text{'udel_done'}<p>\n";
					}
				}

			# Delete from the LDAP db	
			&lock_user_files();
			print "$text{'udel_pass'}<br>\n";
			&delete_user($user);
			print "$text{'udel_done'}<p>\n";

			# Delete from groups
			print "$text{'udel_groups'}<br>\n";
			foreach $g (&list_groups()) {
				@mems = split(/,/, $g->{'members'});
				$idx = &indexof($user->{'user'}, @mems);
				if ($idx >= 0) {
					splice(@mems, $idx, 1);
					%newg = %$g;
					$newg{'members'} = join(',', @mems);
					&modify_group($g, \%newg);
					}
				$mygroup = $g if ($g->{'group'} eq $user->{'user'});
				}
			print "$text{'udel_done'}<p>\n";

			# Delete private group
			if ($mygroup && !$mygroup->{'members'}) {
				local $another;
				foreach $ou (&list_users()) {
					$another = $ou if ($ou->{'gid'} == $mygroup->{'gid'});
					}
				if (!$another) {
					print "$text{'udel_ugroup'}<br>\n";
					&delete_group($mygroup);
					print "$text{'udel_done'}<p>\n";
					}
				}
			&unlock_user_files();

			# Delete his addressbook entry
			if ($config{'addressbook'}) {
				print "$text{'udel_book'}<br>\n";
				$err = &delete_ldap_subtree($ldap, "ou=$user->{'user'}, $config{'addressbook'}");
				if ($err) {
					print &text('udel_failed', $err),"<p>\n";
					}
				else {
					print "$text{'udel_done'}<p>\n";
					}
				}

			# Delete home directory
			if ($in{'delhome'} && $user->{'home'} !~ /^\/+$/) {
				print "$text{'udel_home'}<br>\n";
				if ($config{'delete_only'}) {
					&lock_file($user->{'home'});
					&system_logged("find \"$user->{'home'}\" ! -type d -user $user->{'uid'} | xargs rm -f >/dev/null 2>&1");
					&system_logged("find \"$user->{'home'}\" -type d -user $user->{'uid'} | xargs rmdir >/dev/null 2>&1");
					rmdir($user->{'home'});
					&unlock_file($user->{'home'});
					}
				else {
					&system_logged("rm -rf \"$user->{'home'}\" >/dev/null 2>&1");
					}
				print "$text{'udel_done'}<p>\n";

				# Delete his IMAP mailbox only if home gets
				# deleted, too
				if ($config{'imap_host'}) {
					print "$text{'udel_imap'}<br>\n";
					$imap = &imap_connect();
					$rv = $imap->delete("user".
						$config{'imap_foldersep'}.
						$user->{'user'});
					$imap->logout();
					print "$text{'udel_done'}<p>\n";
					}
				}

			&made_changes();
			print "</ul>\n";
			}

		&webmin_log("delete", "users", scalar(@dlist),
			    { 'user' => [ map { $_->{'user'} } @dlist ] });

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		# Sum up home directories
		foreach $user (@dlist) {
			if ($user->{'home'} ne "/" && -d $user->{'home'}) {
				$size += &disk_usage_kb($user->{'home'});
				}
			}

		# Ask if the user is sure
		print &ui_confirmation_form(
			"mass_delete_user.cgi",
			&text('umass_sure', scalar(@dlist),
			      &nice_size($size*1024)),
			[ [ "confirmed", 1 ],
			  map { [ "d", $_->{'user'} ] } @dlist ],
			[ [ undef, $text{'umass_del1'} ],
			  [ "delhome", $text{'umass_del2'} ] ],
			&ui_checkbox("others", 1, $text{'udel_dothers'},
                             	     $mconfig{'default_other'}),
			$delete_sys && $delete_sys->{'user'} eq 'root' ?
				"<font color=#ff0000>$text{'udel_root'}</font>"
				: ""
			);

		&ui_print_footer("", $text{'index_return'});
		}
	}

