#!/usr/local/bin/perl
# delete_group.cgi
# Delete a group, after asking for confirmation

require './user-lib.pl';
&ReadParse();
@glist = &list_groups();
$group = $glist[$in{'num'}];
$group || &error($text{'gdel_enum'});
$| = 1;
&error_setup($text{'gdel_err'});
%access = &get_module_acl();
&can_edit_group(\%access, $group) || &error($text{'gdel_egroup'});
$access{'gdelete'} || &error($text{'gdel_egroup'});

&ui_print_header(undef, $text{'gdel_title'}, "");

if (!$config{'delete_root'} && $group->{'gid'} <= 10) {
	print "<p> <b>$text{'gdel_eroot'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

if ($in{'confirmed'}) {
	# Check for repeat click
	if ($group->{'group'} ne $in{'group'} || $in{'group'} eq '') {
		print "<p> <b>$text{'gdel_ealready'}</b> <p>\n";
		print &ui_hr();
		&footer("", $text{'index_return'});
		exit;
		}

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
	&webmin_log("delete", "group", $group->{'group'}, $group);
	print "$text{'gdel_done'}<p>\n";

done:
	&ui_print_footer("", $text{'index_return'});
	}
else {
	# check if this is anyone's primary group
	foreach $u (&list_users()) {
		if ($u->{'gid'} == $group->{'gid'}) {
			print "<b>",&text('gdel_eprimary', $u->{'user'}),
			      "</b> <p>\n";
			print &ui_hr();
			&footer("", $text{'index_return'});
			exit;
			}
		}

	# Ask if the user is sure
	print "<form action=delete_group.cgi>\n";
	print "<input type=hidden name=num value=\"$in{'num'}\">\n";
	print "<input type=hidden name=group value=\"$group->{'group'}\">\n";
	print "<input type=hidden name=confirmed value=1>\n";
	print "<center><b>",&text('gdel_sure', $group->{'group'}),"</b><p>\n";
	print "<input type=submit value=\"$text{'gdel_del'}\">\n";
	printf "<br><input type=checkbox name=others value=1 %s> %s<br>\n",
		$config{'default_other'} ? "checked" : "",
		$text{'gdel_dothers'};
	print "</center><p>\n";
	print "</form>\n";
	&ui_print_footer("", $text{'index_return'});
	}

