#!/usr/local/bin/perl
# save_group.cgi
# Saves an existing group

require './cluster-useradmin-lib.pl';
&error_setup($text{'gsave_err'});
&ReadParse();
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

# Get old group
foreach $h (@hosts) {
	foreach $u (@{$h->{'users'}}) {
		$exists{$u->{'user'}}++;
		}
	}

# Strip out \n characters in inputs
$in{'group'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;

# Validate inputs
$in{'gid_def'} || $in{'gid'} =~ /^[0-9]+$/ ||
	&error(&text('gsave_egid', $in{'gid'}));
if ($in{'members_def'} == 1) {
	@add = split(/\s+/, $in{'membersadd'});
	foreach $u (@add) {
		$exists{$u} || &error(&text('gsave_euser', $u));
		}
	}
elsif ($in{'members_def'} == 2) {
	@del = split(/\s+/, $in{'membersdel'});
	foreach $u (@del) {
		$exists{$u} || &error(&text('gsave_euser', $u));
		}
	}

# Setup error handler for down hosts
sub mod_error
{
$mod_error_msg = join("", @_);
}
&remote_error_setup(\&mod_error);

# Do the changes across all hosts
&ui_print_header(undef, $text{'gedit_title'}, "");
foreach $host (@hosts) {
	$mod_error_msg = undef;
	($group) = grep { $_->{'group'} eq $in{'group'} } @{$host->{'groups'}};
	next if (!$group);
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	print "<b>",&text('gsave_uon', $serv->{'desc'} ? $serv->{'desc'} :
				       $serv->{'host'}),"</b><p>\n";
	print "<ul>\n";
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	if ($mod_error_msg) {
		# Host is down ..
		print &text('gsave_failed', $mod_error_msg),"<p>\n";
		print "</ul>\n";
		next;
		}
	local @glist = &remote_foreign_call($serv->{'host'}, "useradmin",
					    "list_groups");
	($group) = grep { $_->{'group'} eq $in{'group'} } @glist;
	if (!$group) {
		}
	local %ogroup = %$group;

	# Update changed fields
	$group->{'gid'} = $in{'gid'} if (!$in{'gid_def'});
	$salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
	if ($in{'passmode'} == 0) {
		$group->{'pass'} = "";
		}
	elsif ($in{'passmode'} == 1) {
		$group->{'pass'} = $in{'encpass'};
		}
	elsif ($in{'passmode'} == 2) {
		$group->{'pass'} = &unix_crypt($in{'pass'}, $salt);
		}
	local @mems = split(/,/, $group->{'members'});
	if (@add) {
		@mems = &unique(@mems, @add);
		}
	elsif (@del) {
		@mems = grep { &indexof($_, @del) < 0 } @mems;
		}
	$group->{'members'} = join(",", @mems);

	# Run the pre-change command
	&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_GROUP'} = '$group->{'group'}';
\$ENV{'USERADMIN_ACTION'} = 'MODIFY_GROUP';
EOF
	);
	$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
				     "making_changes");
	if (defined($merr)) {
		print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
		print "</ul>\n";
		next;
		}

	# Update the group on the server
	print "$text{'gsave_update'}<br>\n";
	&remote_foreign_call($serv->{'host'}, "useradmin", "modify_group",
			     \%ogroup, $group);
	print "$text{'udel_done'}<p>\n";

	# Make file changes
	local @ulist;
	if ($in{'servs'} || $host eq $hosts[0]) {
		if ($group->{'gid'} != $ogroup{'gid'} && $in{'chgid'}) {
			# Change GID on files if needed
			if ($in{'chgid'} == 1) {
				# Do all the home directories of users in
				# this group
				print "$text{'usave_gid'}<br>\n";
				@ulist = &remote_foreign_call($serv->{'host'},
						"useradmin", "list_users");
				foreach $u (@ulist) {
					if ($u->{'gid'} == $ogroup{'gid'} ||
					    &indexof($u->{'user'},@mems) >= 0) {
						&remote_foreign_call(
							$serv->{'host'},
							"useradmin",
							"recursive_change",
							$u->{'home'},
							-1, $ogroup{'gid'},
							-1, $group->{'gid'});
						}
					}
				print "$text{'udel_done'}<p>\n";
				}
			elsif ($in{'chgid'} == 2) {
				# Do all files in this group from the root dir
				print "$text{'usave_gid'}<br>\n";
				&remote_foreign_call($serv->{'host'},
					"useradmin", "recursive_change", "/",
					-1, $ogroup{'gid'}, -1,$group->{'gid'});
				print "$text{'udel_done'}<p>\n";
				}
			}
		}

	# Run the post-change command
	&remote_foreign_call($serv->{'host'}, "useradmin", "made_changes");

	if ($in{'others'}) {
		if (&supports_gothers($serv)) {
			# Update the group in other modules
			print "$text{'usave_mothers'}<br>\n";
			&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_modify_group",
				     $group, \%ogroup);
			print "$text{'udel_done'}<p>\n";
			}
		else {
			# Group syncing not supported
			print "$text{'gsave_nosync'}<p>\n";
			}
		}

	# Update in local list
	$host->{'groups'} = \@glist;
	if (@ulist) {
		$host->{'users'} = \@ulist;
		}
	&save_useradmin_host($host);
	print "</ul>\n";
	}
&webmin_log("modify", "group", $group->{'group'}, $group);

&ui_print_footer("", $text{'index_return'});

