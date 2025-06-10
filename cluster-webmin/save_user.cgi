#!/usr/local/bin/perl
# save_user.cgi
# Update a webmin user on all servers

require './cluster-webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'user_title2'}, "");
print "<b>",&text('user_doing2', $in{'old'}),"</b><p>\n";

@allhosts = &list_webmin_hosts();
foreach $h (@allhosts) {
	foreach $ug (@{$h->{'users'}}, @{$h->{'groups'}}) {
		$taken{$ug->{'name'}}++;
		}
	}

# Validate inputs
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ ||
	&error(&text('user_ename', $in{'name'}));
$in{'name'} ne $in{'old'} && $taken{$in{'name'}} &&
	&error(&text('user_etaken', $in{'name'}));
$in{'pass_def'} == 0 && $in{'pass'} =~ /:/ && &error($text{'user_ecolon'});
if ($in{'ipmode'} > 0) {
	@ips = split(/\s+/, $in{'ips'});
	}

# Setup error handler for down hosts
sub user_error
{
$user_error_msg = join("", @_);
}
&remote_error_setup(\&user_error);

# Update the user on all servers that have him
foreach $h (@allhosts) {
	foreach $u (@{$h->{'users'}}) {
		if ($u->{'name'} eq $in{'old'}) {
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
		if ($user_error_msg) {
			# Host is down
			print $wh &serialise_variable([ 0, $user_error_msg ]);
			exit;
			}

		# Update the user
		($user) = grep { $_->{'name'} eq $in{'old'} } @{$h->{'users'}};
		$user->{'name'} = $in{'name'};
		if (!$in{'lang_def'}) {
			$user->{'lang'} = $in{'lang'} ? $in{'lang'} : undef;
			}
		if (!$in{'theme_def'}) {
			if ($in{'theme'} eq 'webmin') {
				delete($user->{'theme'});
				}
			else {
				$user->{'theme'} = $in{'theme'};
				}
			}
		if ($in{'ipmode'} == 0) {
			delete($user->{'allow'});
			delete($user->{'deny'});
			}
		elsif ($in{'ipmode'} == 1) {
			$user->{'allow'} = join(" ", @ips);
			delete($user->{'deny'});
			}
		elsif ($in{'ipmode'} == 2) {
			delete($user->{'allow'});
			$user->{'deny'} = join(" ", @ips);
			}
		if ($in{'pass_def'} == 0) {
			$salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
			$user->{'pass'} = &unix_crypt($in{'pass'}, $salt);
			$user->{'sync'} = 0;
			}
		elsif ($in{'pass_def'} == 3) {
			$user->{'pass'} = 'x';
			$user->{'sync'} = 0;
			}
		elsif ($in{'pass_def'} == 4) {
			$user->{'pass'} = '*LK*';
			$user->{'sync'} = 0;
			}
		elsif ($in{'pass_def'} == 5) {
			$user->{'pass'} = 'e';
			$user->{'sync'} = 0;
			}

		# Save module categorization setting
		$user->{'notabs'} = $in{'notabs'};

		# Work out which modules the user has
		local @selmods = ( split(/\0/, $in{'mods1'}),
				   split(/\0/, $in{'mods2'}),
				   split(/\0/, $in{'mods3'}) );
		local @mods = @{$user->{'modules'}};
		if ($in{'mods_def'} == 2) {
			@mods = @selmods;
			}
		elsif ($in{'mods_def'} == 3) {
			@mods = &unique(@mods, @selmods);
			}
		elsif ($in{'mods_def'} == 0) {
			@mods = grep { &indexof($_, @selmods) < 0 } @mods;
			}

		# Update old and new groups
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
					[ 0, $text{'user_egroup'} ]);
				exit;
				}
			}
		if (($group ? $group->{'name'} : '') ne
		    ($oldgroup ? $oldgroup->{'name'} : '')) {
			# Group has changed - update the member lists
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

		$user->{'modules'} = \@mods;
		$user->{'ownmods'} = \@ownmods;
		&remote_foreign_call($s->{'host'}, "acl", "modify_user",
				     $in{'old'}, $user);
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
		print &text('user_success2', $d),"<br>\n";
		}
	else {
		# Something went wrong
		print &text('user_failed2', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

print "<p><b>$text{'user_done'}</b><p>\n";

&remote_finished();
&ui_print_footer("", $text{'index_return'});

