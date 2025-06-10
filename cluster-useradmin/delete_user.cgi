#!/usr/local/bin/perl
# delete_user.cgi
# Delete a user, after asking for confirmation

require './cluster-useradmin-lib.pl';
&foreign_require("useradmin", "user-lib.pl");
&ReadParse();
&error_setup($text{'udel_err'});
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

foreach $h (@hosts) {
	local ($u) = grep { $_->{'user'} eq $in{'user'} } @{$h->{'users'}};
	if ($u) {
		%user = %$u;
		last;
		}
	}
%user || &error($text{'udel_ealready'});

# Setup error handler for down hosts
sub del_error
{
$del_error_msg = join("", @_);
}
&remote_error_setup(\&del_error);

$| = 1;
&ui_print_header(undef, $text{'udel_title'}, "");
if ($in{'confirmed'}) {
	# Do the deletion on all hosts
	foreach $host (@hosts) {
		$del_error_msg = undef;
		($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
		($user) = grep { $_->{'user'} eq $in{'user'} }
				     @{$host->{'users'}};
		next if (!$user);
		print "<b>",&text('udel_on', $serv->{'desc'} ? $serv->{'desc'} :
					     $serv->{'host'}),"</b><p>\n";
		print "<ul>\n";
		&remote_foreign_require($serv->{'host'},
					"useradmin", "user-lib.pl");
		if ($del_error_msg) {
			# Host is down ..
			print &text('udel_failed', $del_error_msg),"<p>\n";
			print "</ul>\n";
			next;
			}
		local @ulist = &remote_foreign_call($serv->{'host'},
					"useradmin", "list_users");
		($user) = grep { $_->{'user'} eq $in{'user'} } @ulist;
		if (!$user) {
			# Already deleted?
			print "$text{'udel_gone'}<p>\n";
			print "</ul>\n";
			next;
			}

		# Run the before command
		&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_USER'} = '$user->{'user'}';
\$ENV{'USERADMIN_UID'} = '$user->{'uid'}';
\$ENV{'USERADMIN_REAL'} = '$user->{'real'}';
\$ENV{'USERADMIN_SHELL'} = '$user->{'shell'}';
\$ENV{'USERADMIN_HOME'} = '$user->{'home'}';
\$ENV{'USERADMIN_GID'} = '$user->{'gid'}';
\$ENV{'USERADMIN_ACTION'} = 'DELETE_USER';
EOF
	);
		$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
					     "making_changes");
		if (defined($merr)) {
			print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
			print "</ul>\n";
			next;
			}

		if ($in{'others'}) {
			# Delete from other modules
			print "$text{'udel_dothers'}<br>\n";
			&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_delete_user",
				     $user);
			print "$text{'udel_done'}<p>\n";
			}

		# Delete the user
		print "$text{'udel_pass'}<br>\n";
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "delete_user", $user);
		print "$text{'udel_done'}<p>\n";

		# Delete from any secondary groups
		print "$text{'udel_groups'}<br>\n";
		local @glist = &remote_foreign_call($serv->{'host'},
					"useradmin", "list_groups");
		foreach $g (@glist) {
			local %oldg = %$g;
			local @mems = split(/,/, $g->{'members'});
			$idx = &indexof($user->{'user'}, @mems);
			if ($idx >= 0) {
				splice(@mems, $idx, 1);
				$g->{'members'} = join(',', @mems);
				&remote_foreign_call($serv->{'host'},
				    "useradmin", "modify_group", \%oldg, $g);
				}
			}
		print "$text{'udel_done'}<p>\n";

		# Delete home directory
		if ($in{'servs'} || $host eq $hosts[0]) {
			local $exists = &remote_eval($serv->{'host'},
				"useradmin", "-d '$user{'home'}'");
			if ($in{'delhome'} && $user{'home'} !~ /^\/+$/ &&
			    $exists) {
				print "$text{'udel_home'}<br>\n";
				&remote_eval($serv->{'host'}, "useradmin",
					"system(\"rm -rf '$user{'home'}'\")");
				print "$text{'udel_done'}<p>\n";
				}
			}

		# Run the post-change command
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "made_changes");

		# Update in local list
		@ulist = grep { $_ ne $user } @ulist;
		$host->{'users'} = \@ulist;
		$host->{'groups'} = \@glist;
		&save_useradmin_host($host);
		print "</ul>\n";
		}
	&webmin_log("delete", "user", $user->{'user'}, $user);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Ask if the user is sure
	($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	print "<form action=delete_user.cgi>\n";
	print "<input type=hidden name=user value=\"$user{'user'}\">\n";
	print "<input type=hidden name=confirmed value=1>\n";

	$size = &remote_foreign_call($serv->{'host'}, "useradmin",
				     "disk_usage_kb", $user{'home'});
	print "<center>\n";
	if ($user{'home'} ne "/" && $size) {
		print "<b>",&text('udel_sure', $user{'user'},
				  $user{'home'}, $size),"</b><p>\n";
		print "<input type=submit value=\"$text{'udel_del1'}\">\n";
		print "<input name=delhome type=submit ",
		      "value=\"$text{'udel_del2'}\"><br>\n";
		print "<b>$text{'udel_servs'}</b>\n";
		print "<input type=radio name=servs value=1> ",
		      "$text{'uedit_mall'}\n";
		print "<input type=radio name=servs value=0 checked> ",
		      "$text{'uedit_mthis'}<br>\n";
		}
	else {
		print "<center><b>",&text('udel_sure2',
					   $user{'user'}),"</b><p>\n";
		print "<input type=submit value=\"$text{'udel_del1'}\">\n";
		}
	if ($user{'user'} eq 'root') {
		print "<b><font color=#ff0000>$text{'udel_root'}",
		      "</font></b></center>\n";
		}

	print "<br><b>$text{'udel_others'}</b>\n";
	print "<input type=radio name=others value=1 checked> $text{'yes'}\n";
	print "<input type=radio name=others value=0> $text{'no'}\n";

	print "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	}

