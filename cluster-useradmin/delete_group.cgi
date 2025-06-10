#!/usr/local/bin/perl
# delete_group.cgi
# Delete a group, after asking for confirmation

require './cluster-useradmin-lib.pl';
&ReadParse();
&error_setup($text{'gdel_err'});
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

foreach $h (@hosts) {
	local ($g) = grep { $_->{'group'} eq $in{'group'} } @{$h->{'groups'}};
	if ($g) {
		%group = %$g;
		last;
		}
	}
%group || &error($text{'gdel_ealready'});

# Setup error handler for down hosts
sub del_error
{
$del_error_msg = join("", @_);
}
&remote_error_setup(\&del_error);

$| = 1;
&ui_print_header(undef, $text{'gdel_title'}, "");
if ($in{'confirmed'}) {
	# Do the deletion on all hosts
	foreach $host (@hosts) {
		$del_error_msg = undef;
		($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
		($group) = grep { $_->{'group'} eq $in{'group'} }
				     @{$host->{'groups'}};
		next if (!$group);
		print "<b>",&text('gdel_on', $serv->{'desc'} ? $serv->{'desc'} :
					     $serv->{'host'}),"</b><p>\n";
		print "<ul>\n";
		&remote_foreign_require($serv->{'host'},
					"useradmin", "user-lib.pl");
		if ($del_error_msg) {
			# Host is down ..
			print &text('gdel_failed', $del_error_msg),"<p>\n";
			print "</ul>\n";
			next;
			}
		local @glist = &remote_foreign_call($serv->{'host'},
					"useradmin", "list_groups");
		($group) = grep { $_->{'group'} eq $in{'group'} } @glist;
		if (!$group) {
			# Already deleted?
			print "$text{'gdel_gone'}<p>\n";
			print "</ul>\n";
			next;
			}

		# Delete from other modules
		if ($in{'others'}) {
			if (&supports_gothers($serv)) {
				# Delete in other modules on the server
				print "$text{'gdel_other'}<br>\n";
				&remote_foreign_call($serv->{'host'},
					"useradmin", "other_modules",
					"useradmin_delete_group", $group);
				print "$text{'gdel_done'}<p>\n";
				}
			else {
				# Group syncing not supported
				print "$text{'gsave_nosync'}<p>\n";
				}
			}

		# Run the pre-change command
		&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_GROUP'} = '$group->{'group'}';
\$ENV{'USERADMIN_ACTION'} = 'DELETE_GROUP';
EOF
		);
		$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
					     "making_changes");
		if (defined($merr)) {
			print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
			print "</ul>\n";
			next;
			}

		# Delete the group
		print "$text{'gdel_group'}<br>\n";
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "delete_group", $group);
		print "$text{'gdel_done'}<p>\n";

		# Run the post-change command
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "made_changes");

		# Update in local list
		@glist = grep { $_ ne $group } @glist;
		$host->{'groups'} = \@glist;
		&save_useradmin_host($host);
		print "</ul>\n";
		}
	&webmin_log("delete", "group", $group->{'group'}, $group);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Check if this is anyone's primary group
	foreach $h (@hosts) {
		foreach $u (@{$h->{'users'}}) {
			if ($u->{'gid'} == $group{'gid'}) {
				$puser = $u;
				last;
				}
			}
		}
	if ($puser) {
		print "<b>",&text('gdel_eprimary', $puser->{'user'}),
		      "</b><p>\n";
		&ui_print_footer("", $text{'index_return'});
		exit;
		}

	# Ask if the user is sure
	print "<form action=delete_group.cgi>\n";
	print "<input type=hidden name=group value=\"$group{'group'}\">\n";
	print "<input type=hidden name=confirmed value=1>\n";

	print "<center><b>",&text('gdel_sure',
				   $group{'group'}),"</b>\n";
	print "<input type=submit value=\"$text{'gdel_del'}\">\n";
	print "<br><input type=checkbox name=others value=1 checked> ",
	      "$text{'gdel_dothers'}<br>\n";
	print "</center><p>\n";
	print "</form>\n";
	&ui_print_footer("", $text{'index_return'});
	}

