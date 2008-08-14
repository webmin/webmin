#!/usr/local/bin/perl
# delete_user.cgi
# Delete a user, after asking for confirmation

require './user-lib.pl';
&ReadParse();
&lock_user_files();
@ulist = &list_users();
$user = $ulist[$in{'num'}];
$user || &error($text{'udel_enum'});
&error_setup($text{'udel_err'});
&can_edit_user(\%access, $user) || &error($text{'udel_euser'});
$access{'udelete'} || &error($text{'udel_euser'});

$| = 1;
&ui_print_header(undef, $text{'udel_title'}, "");

if (!$config{'delete_root'} && $user->{'uid'} <= 10) {
	print "<p> <b>$text{'udel_eroot'}</b> <p>\n";
	print &ui_hr();
	&footer("", $text{'index_return'});
	exit;
	}

# Check for repeat click
if ($user->{'user'} ne $in{'user'} || $in{'user'} eq '') {
	print "<p> <b>$text{'udel_ealready'}</b> <p>\n";
	print &ui_hr();
	&footer("", $text{'index_return'});
	exit;
	}

if ($in{'confirmed'}) {
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
	&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

	# Go ahead and do it!
	$in{'others'} = !$access{'dothers'} if ($access{'dothers'} != 1);
	if ($in{'others'}) {
		print "$text{'udel_other'}<br>\n";
		local $error_must_die = 1;
		eval { &other_modules("useradmin_delete_user", $user); };
		if ($@) {
			print &text('udel_failed', $@),"<p>\n";
			}
		else {
			print "$text{'udel_done'}<p>\n";
			}
		}
	
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

	if ($in{'delhome'} && $user->{'home'} !~ /^\/+$/ && $access{'delhome'} != 0) {
		# Delete home directory
		print "$text{'udel_home'}<br>\n";
		&lock_file($user->{'home'});
		&delete_home_directory($user);
		&unlock_file($user->{'home'});
		print "$text{'udel_done'}<p>\n";
		}

	&made_changes();

	%p = ( %in, %$user );
	delete($p{'pass'});
	&webmin_log("delete", "user", $user->{'user'}, \%p);

done:
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Check if something has changed
	if ($user->{'user'} ne $in{'user'}) {
		print "<p> <b>$text{'udel_echanged'}</b> <p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}

	# Ask if the user is sure
	print "<form action=delete_user.cgi>\n";
	print "<input type=hidden name=num value=\"$in{'num'}\">\n";
	print "<input type=hidden name=user value=\"$user->{'user'}\">\n";
	print "<input type=hidden name=confirmed value=1>\n";

	if ($user->{'home'} ne "/" && -d $user->{'home'} && $access{'delhome'} != 0) {
		# Has a home directory, so check for files owned by others
		$size = &disk_usage_kb($user->{'home'});
		print "<center><b>",&text('udel_sure', $user->{'user'},
			   "<tt>$user->{'home'}</tt>", &nice_size($size*1024)),
			   "</b><p>\n";
		if ($access{'delhome'} != 1) {
			print "<input type=submit value=\"$text{'udel_del1'}\">\n";
			}
		print "<input name=delhome type=submit ",
		      "value=\"$text{'udel_del2'}\">\n";

		# check for files owned by other users
		@others = &backquote_command("find ".quotemeta($user->{'home'})." ! -user $user->{'uid'} 2>/dev/null", 1);
		if (@others) {
			print "<br><b><font color=#ff0000>",
			      &text('udel_others', "<tt>$user->{'home'}</tt>", scalar(@others)),
			      "</font></b><br>\n";
			}
		}
	else {
		# No home directory
		print "<center><b>",&text('udel_sure2',
					   $user->{'user'}),"</b><p>\n";
		print "<input type=submit value=\"$text{'udel_del1'}\">\n";
		}
	print "<br>\n";
	if ($access{'dothers'} == 1) {
		printf "<input type=checkbox name=others value=1 %s> %s<br>\n",
			$config{'default_other'} ? "checked" : "",
	      		$text{'udel_dothers'};
		}
	if ($user->{'user'} eq 'root') {
		print "<center><b><font color=#ff0000>$text{'udel_root'}",
		      "</font></b><p></center>\n";
		}
	print "</form></center>\n";

	&ui_print_footer("", $text{'index_return'});
	}

