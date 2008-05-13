#!/usr/local/bin/perl
# sync.cgi
# Create missing users and groups on servers

require './cluster-useradmin-lib.pl';
&ReadParse();
@hosts = &list_useradmin_hosts();
@servers = &list_servers();
&ui_print_header(undef, $text{'sync_title'}, "");

# Work out which hosts to sync on
@phosts = &create_on_parse(undef, undef, undef, 1);

# Build lists of all users and group
foreach $h (@hosts) {
	foreach $u (@{$h->{'users'}}) {
		push(@ulist, $u) if (!$doneuser{$u->{'user'}}++);
		}
	foreach $g (@{$h->{'groups'}}) {
		push(@glist, $g) if (!$donegroup{$g->{'group'}}++);
		}
	}

# Find users and groups to sync
if ($in{'users_mode'} == 1) {
	@usync = @ulist;
	}
elsif ($in{'users_mode'} == 2) {
	map { $usel{$_}++ } split(/\s+/, $in{'usel'});
	@usync = grep { $usel{$_->{'user'}} } @ulist;
	}
elsif ($in{'users_mode'} == 3) {
	map { $unot{$_}++ } split(/\s+/, $in{'unot'});
	@usync = grep { !$unot{$_->{'user'}} } @ulist;
	}
elsif ($in{'users_mode'} == 4) {
	@usync = grep { (!$in{'uuid1'} || $_->{'uid'} >= $in{'uuid1'}) &&
			(!$in{'uuid2'} || $_->{'uid'} <= $in{'uuid2'}) } @ulist;
	}
elsif ($in{'users_mode'} == 5) {
	local $gid = getgrnam($in{'ugid'});
	@usync = grep { $_->{'gid'} == $gid } @ulist if (defined($gid));
	}

if ($in{'groups_mode'} == 1) {
	@gsync = @glist;
	}
elsif ($in{'groups_mode'} == 2) {
	map { $gsel{$_}++ } split(/\s+/, $in{'gsel'});
	@gsync = grep { $gsel{$_->{'group'}} } @glist;
	}
elsif ($in{'groups_mode'} == 3) {
	map { $gnot{$_}++ } split(/\s+/, $in{'gnot'});
	@gsync = grep { !$gnot{$_->{'group'}} } @glist;
	}
elsif ($in{'groups_mode'} == 4) {
	@gsync = grep { (!$in{'ggid1'} || $_->{'gid'} >= $in{'ggid1'}) &&
			(!$in{'ggid2'} || $_->{'gid'} <= $in{'ggid2'}) } @glist;
	}

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Sync on chosen hosts
foreach $host (@phosts) {
	$add_error_msg = undef;
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	print "<b>",&text('sync_on', $serv->{'desc'} ? $serv->{'desc'} :
				     $serv->{'host'}),"</b><p>\n";
	print "<ul>\n";

	# Find missing users and groups
	local (%usync, %gsync);
	map { $usync{$_->{'user'}}++ } @{$host->{'users'}};
	map { $gsync{$_->{'group'}}++ } @{$host->{'groups'}};
	local @uneed = grep { !$usync{$_->{'user'}} } @usync;
	local @gneed = grep { !$gsync{$_->{'group'}} } @gsync;
	if (@uneed || @gneed) {
		&remote_foreign_require($serv->{'host'},
					"useradmin", "user-lib.pl");
		if ($add_error_msg) {
			# Host is down!
			print "$add_error_msg<p>\n";
			print "</ul>\n";
			next;
			}

		# Create missing users
		foreach $u (@uneed) {
			# Create the user
			print &text('sync_ucreate', $u->{'user'}),"<br>\n";
			if (!$in{'test'}) {
				&remote_foreign_call($serv->{'host'},
					"useradmin", "create_user", $u);
				push(@{$host->{'users'}}, $u);
				}
			print "$text{'udel_done'}<p>\n";

			local $made_home;
			if ($in{'makehome'}) {
				# Create the home directory
				local $exists = &remote_eval($serv->{'host'},
					"useradmin", "-d '$u->{'home'}'");
				if (!$exists) {
					print "$text{'usave_mkhome'}<br>\n";
					if (!$in{'test'}) {
						local $rv = &remote_eval($serv->{'host'}, "useradmin", "&make_dir('$u->{'home'}', oct('$uconfig{'homedir_perms'}'), 1) && chmod(oct('$uconfig{'homedir_perms'}'), '$u->{'home'}') ? undef : \$!");
						$rv && &error(&text(
							'usave_emkdir', $rv));

						$rv = &remote_eval($serv->{'host'}, "useradmin", "chown($u->{'uid'}, $u->{'gid'}, '$u->{'home'}')");
						$rv || &error(&text(
							'usave_echown', $rv));
						}
					$made_home = 1;
					print "$text{'udel_done'}<p>\n";
					}
				}

			if ($in{'others'}) {
				# Create in other modules on the server
				print "$text{'usave_others'}<br>\n";
				if (!$in{'test'}) {
					$u->{'passmode'} = 2;
					&remote_foreign_call(
						$serv->{'host'}, "useradmin",
						"other_modules",
						"useradmin_create_user", $u);
					}
				print "$text{'udel_done'}<p>\n";
				}

			if ($in{'copy_files'} && $made_home) {
				# Copy files to new home directory
				local $fconfig = &remote_foreign_config(
						$serv->{'host'}, "useradmin");
				print "$text{'usave_copy'}<br>\n";
				local $uf = $fconfig->{'user_files'};
				local $gn = getgrgid($u->{'gid'});
				$uf =~ s/\$group/$gn/g;
				$uf =~ s/\$gid/$u->{'gid'}/g;
				&remote_foreign_call($serv->{'host'},
					"useradmin",
					"copy_skel_files", $uf, $u->{'home'},
					$u->{'uid'}, $u->{'gid'})
					if (!$in{'test'});
				print "$text{'udel_done'}<p>\n";
				}
			}

		# Create missing groups
		foreach $g (@gneed) {
			print &text('sync_gcreate', $g->{'group'}),"<br>\n";
			if (!$in{'test'}) {
				&remote_foreign_call($serv->{'host'},
					"useradmin", "create_group", $g);
				push(@{$host->{'groups'}}, $g);
				}
			print "$text{'udel_done'}<p>\n";
			}

		# Update in local list
		&save_useradmin_host($host);
		}
	else {
		print "$text{'sync_insync'}<p>\n";
		}
	print "</ul>\n";
	}
&webmin_log("sync", undef, undef, \%in);

&ui_print_footer("", $text{'index_return'});

