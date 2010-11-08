#!/usr/local/bin/perl
# save_group.cgi
# Update a webmin group on all servers

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'group_title2'}, "");
print "<b>",&text('group_doing2', $in{'old'}),"</b><p>\n";

@allhosts = &list_webmin_hosts();
foreach $h (@allhosts) {
	foreach $ug (@{$h->{'users'}}, @{$h->{'groups'}}) {
		$taken{$ug->{'name'}}++;
		}
	}

# Validate inputs
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ ||
	&error(&text('group_ename', $in{'name'}));
$in{'name'} ne $in{'old'} && $taken{$in{'name'}} &&
	&error(&text('group_etaken', $in{'name'}));

# Setup error handler for down hosts
sub group_error
{
$group_error_msg = join("", @_);
}
&remote_error_setup(\&group_error);

# Update the group on all servers that have it
foreach $h (@allhosts) {
	foreach $g (@{$h->{'groups'}}) {
		if ($g->{'name'} eq $in{'old'}) {
			push(@hosts, $h);
			last;
			}
		}
	}
@servers = &list_servers();
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
		if ($group_error_msg) {
			# Host is down
			print $wh &serialise_variable([ 0, $group_error_msg ]);
			exit;
			}

		# Update the user
		($edgrp) = grep { $_->{'name'} eq $in{'old'} } @{$h->{'groups'}};
		$edgrp->{'name'} = $in{'name'};

		# Work out which modules the group has
		local @selmods = ( split(/\0/, $in{'mods1'}),
				   split(/\0/, $in{'mods2'}),
				   split(/\0/, $in{'mods3'}) );
		local @mods = @{$edgrp->{'modules'}};
		if ($in{'mods_def'} == 2) {
			@mods = @selmods;
			}
		elsif ($in{'mods_def'} == 3) {
			@mods = &unique(@mods, @selmods);
			}
		elsif ($in{'mods_def'} == 0) {
			@mods = grep { &indexof($_, @selmods) < 0 } @mods;
			}

		# Update old and new parent groups
		foreach $g (@{$h->{'groups'}}) {
			if (&indexof($in{'old'}, @{$g->{'members'}}) >= 0) {
				$oldgroup = $g;
				}
			}
		if ($in{'group_def'}) {
			$group = $oldgroup;
			}
		else {
			($group) = grep { $_->{'name'} eq $in{'group'} }
					@{$h->{'groups'}};
			if (!$group && $in{'group'}) {
				print $wh &serialise_variable(
					[ 0, $text{'group_egroup'} ]);
				exit;
				}
			}
		if (($group ? $group->{'name'} : '') ne
		    ($oldgroup ? $oldgroup->{'name'} : '')) {
			# Parent group has changed - update the member lists
			if ($oldgroup) {
				$oldgroup->{'members'} =
					[ grep { $_ ne $in{'old'} }
					       @{$oldgroup->{'members'}} ];
				&remote_foreign_call($s->{'host'}, "acl",
				    "modify_group", $oldgroup->{'name'}, $oldgroup);
				}
			if ($group) {
				push(@{$group->{'members'}}, $in{'name'});
				&remote_foreign_call($s->{'host'}, "acl",
				    "modify_group", $group->{'name'}, $group);
				}
			}

		if ($oldgroup) {
			# Remove modules from the old group
			@mods = grep { &indexof($_, @{$oldgroup->{'modules'}}) < 0 }
				     @mods;
			}

		@ownmods = ( );
		if ($group) {
			# Add modules from new group
			foreach $m (@mods) {
				push(@ownmods, $m)
				    if (&indexof($m, @{$group->{'modules'}}) < 0);
				}
			@mods = &unique(@mods, @{$group->{'modules'}});
			&remote_foreign_call($s->{'host'}, "acl",
				"copy_acl_files", $group->{'name'}, $in{'old'},
				[ @{$group->{'modules'}}, "" ]);
			}

		$edgrp->{'modules'} = \@mods;
		$edgrp->{'ownmods'} = \@ownmods;
		&remote_foreign_call($s->{'host'}, "acl", "modify_group",
				     $in{'old'}, $edgrp);

		# Recursively update all member users and groups
		&remote_foreign_call($s->{'host'}, "acl", "update_members",
				     $h->{'users'}, $h->{'groups'},
				     $edgrp->{'modules'}, $edgrp->{'members'});
		@freshusers = &remote_foreign_call($s->{'host'}, "acl",
						   "list_users");
		$h->{'users'} = \@freshusers;
		@freshgroups = &remote_foreign_call($s->{'host'}, "acl",
						    "list_groups");
		$h->{'groups'} = \@freshgroups;
		&save_webmin_host($h);

		# Restart the remote webmin
		print $wh &serialise_variable([ 1 ]);
		&remote_foreign_call($s->{'host'}, "acl", "restart_miniserv");
		exit;
		}
	close($wh);
	$p++;
	}

# Read back the results
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);
	local $rh = "READ$p";
	local $line = <$rh>;
	local $rv = &unserialise_variable($line);
	close($rh);

	if ($rv && $rv->[0] == 1) {
		# It worked
		print &text('group_success2', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('group_failed2', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'group_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

