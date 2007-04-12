#!/usr/local/bin/perl
# mass_delete_user.cgi
# Delete multiple users, after asking for confirmation

require './user-lib.pl';
&ReadParse();
%access = &get_module_acl();
%ulist = map { $_->{'user'}, $_ } &list_users();
&error_setup($text{'umass_err'});
foreach $name (split(/\0/, $in{'d'})) {
	$user = $ulist{$name};
	if ($user) {
		&can_edit_user(\%access, $user) ||
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
			if ($user->{'pass'} !~ /^$disable_string/) {
				$user->{'pass'} =
					$disable_string.$user->{'pass'};
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
		print "<form action=mass_delete_user.cgi method=post>\n";
		print "<input type=hidden name=confirmed value=1>\n";
		print "<input type=hidden name=disable value=1>\n";
		foreach $user (@dlist) {
			print "<input type=hidden name=d value='$user->{'user'}'>\n";
			}

		# Show buttons
		print "<center><b>",&text('dmass_sure',
				   scalar(@dlist)),"</b><p>\n";
		print "<input type=submit value=\"$text{'dmass_dis'}\">\n";
		print "<br>\n";
		print "</form></center>\n";

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
		if ($user->{'pass'} =~ s/^$disable_string//) {
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
	$access{'udelete'} || &error($text{'udel_euser'});
	&ui_print_unbuffered_header(undef, $text{'umass_title'}, "");

	# Check for deletion of system user
	if (!$config{'delete_root'} && $delete_sys) {
		print "<p> <b>",&text('umass_eroot',
				      $delete_root->{'user'}),"</b> <p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}

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
			$others = $config{'default_other'};
			$others = !$access{'dothers'}
				if ($access{'dothers'} != 1);
			if ($others) {
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
			
			&lock_user_files();
			print "$text{'udel_pass'}<br>\n";
			&delete_user($user);
			print "$text{'udel_done'}<p>\n";

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

			if ($in{'delhome'} && $user->{'home'} !~ /^\/+$/) {
				print "$text{'udel_home'}<br>\n";
				&lock_file($user->{'home'});
				&delete_home_directory($user);
				&unlock_file($user->{'home'});
				print "$text{'udel_done'}<p>\n";
				}

			&made_changes();
			print "</ul>\n";
			}

		&webmin_log("delete", "users", scalar(@dlist),
			    { 'user' => [ map { $_->{'user'} } @dlist ] });

		&ui_print_footer("", $text{'index_return'});
		}
	else {
		# Ask if the user is sure
		print "<form action=mass_delete_user.cgi method=post>\n";
		print "<input type=hidden name=confirmed value=1>\n";
		foreach $user (@dlist) {
			print "<input type=hidden name=d value='$user->{'user'}'>\n";
			}

		# Sum up home directories
		foreach $user (@dlist) {
			if ($user->{'home'} ne "/" && -d $user->{'home'}) {
				$size += &disk_usage_kb($user->{'home'});
				}
			}

		# Show buttons
		print "<center><b>",&text('umass_sure',
			   scalar(@dlist), &nice_size($size*1024)),"</b><p>\n";

		if ($access{'delhome'} == 1) {
			# Force home directory deletion
			print &ui_hidden("delhome", 1),"\n";
			print &ui_submit($text{'umass_del2'}),"\n";
			}
		elsif ($access{'delhome'} == 0) {
			# Never allow home directory deletion
			print &ui_submit($text{'umass_del1'}),"\n";
			}
		else {
			print &ui_submit($text{'umass_del1'}),"\n";
			print &ui_submit($text{'umass_del2'}, "delhome"),"\n";
			}

		print "<br>\n";
		printf "<input type=checkbox name=others value=1 %s> %s<br>\n",
			$config{'default_other'} ? "checked" : "",
	      		$text{'udel_dothers'};
		if ($delete_sys && $delete_sys->{'user'} eq 'root') {
			print "<center><b><font color=#ff0000>$text{'udel_root'}",
			      "</font></b><p></center>\n";
			}
		print "</form></center>\n";

		&ui_print_footer("", $text{'index_return'});
		}
	}

