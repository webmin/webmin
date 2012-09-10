#!/usr/local/bin/perl
# save_user.cgi
# Updates an existing user across multiple servers

require './cluster-useradmin-lib.pl';
use Time::Local;
&error_setup($text{'usave_err'});
&ReadParse();
&foreign_require("useradmin", "user-lib.pl");

# Strip out \n characters in inputs
$in{'real'} =~ s/\r|\n//g;
$in{'user'} =~ s/\r|\n//g;
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'home'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;
$in{'uid'} =~ s/\r|\n//g;
$in{'othersh'} =~ s/\r|\n//g;

# Validate username
$user{'user'} = $in{'user'};
$in{'user'} =~ /^[^:\t]+$/ ||
	&error(&text('usave_ebadname', $in{'user'}));
$err = &useradmin::check_username_restrictions($in{'user'});
&error($err) if ($err);

# Get host and old user
@hosts = &list_useradmin_hosts();
@servers = &list_servers();
($host) = grep { $_->{'id'} == $in{'id'} } @hosts;
if ($in{'user'} ne $in{'olduser'}) {
	# Renaming .. check for clash
	foreach $h (@hosts) {
		local $ou = grep { $_->{'user'} eq $in{'olduser'} }
				 @{$h->{'users'}};
		local $nu = grep { $_->{'user'} eq $in{'user'} }
				 @{$h->{'users'}};
		local ($serv) = grep { $_->{'id'} == $h->{'id'} } @servers;
		&error(&text('usave_einuse', $serv->{'host'})) if ($ou && $nu)
		}
	}

# Validate basic inputs
$in{'uid_def'} || $in{'uid'} =~ /^[0-9]+$/ ||
	&error(&text('usave_euid', $in{'uid'}));
$in{'real_def'} || $in{'real'} =~ /^[^:]*$/ ||
	&error(&text('usave_ereal', $in{'real'}));
$in{'gid_def'} || defined(getgrnam($in{'gid'})) ||
	&error(&text('usave_egid', $in{'gid'}));
if ($uconfig{'extra_real'}) {
	$in{'office_def'} || $in{'office'} =~ /^[^:]*$/ ||
		&error($text{'usave_eoffice'});
	$in{'workph_def'} || $in{'workph'} =~ /^[^:]*$/ ||
		&error($text{'usave_eworkph'});
	$in{'homeph_def'} || $in{'homeph'} =~ /^[^:]*$/ ||
		&error($text{'usave_ehomeph'});
	}
$in{'home_def'} || $in{'home'} =~ /^\// ||
	&error(&text('usave_ehome', $in{'home'}));

# Validate password
if ($in{'passmode'} == 3) {
	local $err = &useradmin::check_password_restrictions(
			$in{'pass'}, $user{'user'}, \%user);
	&error($err) if ($err);
	}

$pft = &foreign_call("useradmin", "passfiles_type");
if ($pft == 2) {
	# Validate shadow-password inputs
	if (!$in{'expire_def'} && $in{'expired'} ne "" &&
	    $in{'expirem'} ne "" && $in{'expirey'} ne "") {
		eval { $expire = timelocal(0, 0, 12, $in{'expired'},
					   $in{'expirem'}-1,
					   $in{'expirey'}-1900); };
		if ($@) { &error($text{'usave_eexpire'}); }
		$expire = int($expire / (60*60*24));
		}
	else { $expire = ""; }
	$in{'min_def'} || $in{'min'} =~ /^[0-9]*$/ ||
		&error(&text('usave_emin', $in{'min'}));
	$in{'max_def'} || $in{'max'} =~ /^[0-9]*$/ ||
		&error(&text('usave_emax', $in{'max'}));
	$in{'warn_def'} || $in{'warn'} =~ /^[0-9]*$/ ||
		&error(&text('usave_ewarn', $in{'warn'}));
	$in{'inactive_def'} || $in{'inactive'} =~ /^[0-9]*$/ ||
		&error(&text('usave_einactive', $in{'inactive'}));
	}
elsif ($pft == 1 || $pft == 6) {
	# Validate BSD password inputs
	if (!$in{'expire_def'} && $in{'expired'} ne "" &&
	    $in{'expirem'} ne "" && $in{'expirey'} ne "") {
		eval { $expire = timelocal(59, $in{'expiremi'},
					   $in{'expireh'},
					   $in{'expired'},
					   $in{'expirem'}-1,
					   $in{'expirey'}-1900); };
		if ($@) { &error($text{'usave_eexpire'}); }
		}
	else { $expire = ""; }
	if (!$in{'change_def'} && $in{'changed'} ne "" &&
	    $in{'changem'} ne "" && $in{'changey'} ne "") {
		eval { $change = timelocal(59, $in{'changemi'},
					   $in{'changeh'},
					   $in{'changed'},
					   $in{'changem'}-1,
					   $in{'changey'}-1900); };
		if ($@) { &error($text{'usave_echange'}); }
		}
	else { $change = ""; }
	$in{'class_def'} || $in{'class'} =~ /^([^: ]*)$/ ||
		&error(&text('usave_eclass', $in{'class'}));
	}
elsif ($pft == 4) {
	# Validate AIX password inputs
	if (!$in{'expire_def'} && $in{'expired'} ne "" && $in{'expirem'} ne ""	
		&& $in{'expirey'} ne "" ) {
		# Add a leading zero if only 1 digit long
		$in{'expirem'} =~ s/^(\d)$/0$1/;
		$in{'expired'} =~ s/^(\d)$/0$1/;
		$in{'expireh'} =~ s/^(\d)$/0$1/;
		$in{'expiremi'} =~ s/^(\d)$/0$1/;
		
		# Only use the last two digits of the year
		$in{'expirey'} =~ s/^\d\d(\d\d)$/$1/;
		
		# If the user didn't choose the hour and min make them 01
		$in{'expireh'} = "01" if $in{'expireh'} eq "";
		$in{'expiremi'} = "01" if $in{'expiremi'} eq "";
		$expire="$in{'expirem'}$in{'expired'}$in{'expireh'}$in{'expiremi'}$in{'expirey'}";
		}
	else { $expire = ""; }
	}

# Validate groups
foreach $h (@hosts) {
	map { $hasgroup{$_->{'group'}}++ } @{$h->{'groups'}};
	}
@check = $in{'sgid_def'} == 1 ? split(/\s+/, $in{'sgidadd'}) :
	 $in{'sgid_def'} == 2 ? split(/\s+/, $in{'sgiddel'}) : ( );
foreach $c (@check) {
	$hasgroup{$c} || &error(&text('usave_esecgid', $c));
	}

# Setup error handler for down hosts
sub mod_error
{
$mod_error_msg = join("", @_);
}
&remote_error_setup(\&mod_error);

# Do the changes across all hosts
&ui_print_header(undef, $text{'uedit_title'}, "");
$crypted = &foreign_call("useradmin", "encrypt_password", $in{'pass'});
foreach $host (@hosts) {
	$mod_error_msg = undef;
	($user) = grep { $_->{'user'} eq $in{'olduser'} } @{$host->{'users'}};
	next if (!$user);
	local ($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
	print "<b>",&text('usave_uon', $serv->{'desc'} ? $serv->{'desc'} :
				       $serv->{'host'}),"</b><p>\n";
	print "<ul>\n";
	&remote_foreign_require($serv->{'host'}, "useradmin", "user-lib.pl");
	if ($mod_error_msg) {
		# Host is down ..
		print &text('usave_failed', $mod_error_msg),"<p>\n";
		print "</ul>\n";
		next;
		}
	local @ulist = &remote_foreign_call($serv->{'host'}, "useradmin",
					    "list_users");
	($user) = grep { $_->{'user'} eq $in{'olduser'} } @ulist;
	if (!$user) {
		# No longer exists?
		print "$text{'usave_gone'}<p>\n";
		print "</ul>\n";
		next;
		}
	local %ouser = %$user;

	# Update changed fields
	$user->{'user'} = $in{'user'};
	$user->{'olduser'} = $ouser{'user'};
	$user->{'uid'} = $in{'uid'} if (!$in{'uid_def'});
	if ($uconfig{'extra_real'}) {
		local @real = split(/,/, $user->{'real'});
		$real[0] = $in{'real'} if (!$in{'real_def'});
		$real[1] = $in{'office'} if (!$in{'office_def'});
		$real[2] = $in{'workph'} if (!$in{'workph_def'});
		$real[3] = $in{'homeph'} if (!$in{'homeph_def'});
		$real[4] = $in{'extra'} if (!$in{'extra_def'});
		$user->{'real'} = join(",", @real);
		}
	else {
		$user->{'real'} = $in{'real'} if (!$in{'real_def'});
		}
	if ($in{'home_def'} == 2) {
		$user->{'home'} = &auto_home_dir($uconfig{'home_base'},
						 $in{'user'});
		}
	elsif ($in{'home_def'} == 0) {
		$user->{'home'} = $in{'home'};
		}
	$user->{'shell'} = $in{'shell'} if (!$in{'shell_def'});
	if ($in{'passmode'} == 0) {
		$user->{'pass'} = "";
		}
	elsif ($in{'passmode'} == 1) {
		$user->{'pass'} = $uconfig{'lock_string'};
		}
	elsif ($in{'passmode'} == 2) {
		$user->{'pass'} = $in{'encpass'};
		}
	elsif ($in{'passmode'} == 3) {
		$user->{'pass'} = $crypted;
		}
	$user->{'passmode'} = $in{'passmode'} < 0 ? 2 : $in{'passmode'};
	$user->{'gid'} = getgrnam($in{'gid'}) if (!$in{'gid_def'});

	if ($pft == 1 || $pft == 6) {
		# Save BSD password inputs
		$user->{'expire'} = $expire if (!$in{'expire_def'});
		$user->{'change'} = $change if (!$in{'change_def'});
		$user->{'class'} = $in{'class'} if (!$in{'class_def'});
		}
	elsif ($pft == 2) {
		# Save shadow password inputs
		$user->{'min'} = $in{'min'} if (!$in{'min_def'});
		$user->{'max'} = $in{'max'} if (!$in{'max_def'});
		$user->{'warn'} = $in{'warn'} if (!$in{'warn_def'});
		$user->{'inactive'} = $in{'inactive'} if (!$in{'inactive_def'});
		$user->{'expire'} = $expire if (!$in{'expire_def'});
		$user->{'change'} = 0 if ($in{'forcechange'});
		}
	elsif ($pft == 4) {
		# Save AIX password inputs
		if (!$in{'flags_def'}) {
			$user->{'admin'} = $in{'flags'} =~ /admin/;
			$user->{'admchg'} = $in{'flags'} =~ /admchg/;
			$user->{'nocheck'} = $in{'flags'} =~ /nocheck/;
			}
		$user->{'expire'} = $expire if (!$in{'expire_def'});
		$user->{'min'} = $in{'min'} if (!$in{'min_def'});
		$user->{'max'} = $in{'max'} if (!$in{'max_def'});
		$user->{'warn'} = $in{'warn'} if (!$in{'warn_def'});
		}

	# Run the pre-change command
	$envpass = $in{'passmode'} == 3 ? $in{'pass'} : undef;
	&remote_eval($serv->{'host'}, "useradmin", <<EOF
\$ENV{'USERADMIN_USER'} = '$user->{'user'}';
\$ENV{'USERADMIN_UID'} = '$user->{'uid'}';
\$ENV{'USERADMIN_REAL'} = '$user->{'real'}';
\$ENV{'USERADMIN_SHELL'} = '$user->{'shell'}';
\$ENV{'USERADMIN_HOME'} = '$user->{'home'}';
\$ENV{'USERADMIN_GID'} = '$user->{'gid'}';
\$ENV{'USERADMIN_PASS'} = '$envpass';
\$ENV{'USERADMIN_ACTION'} = 'MODIFY_USER';
EOF
	);
	$merr = &remote_foreign_call($serv->{'host'}, "useradmin",
				     "making_changes");
	if (defined($merr)) {
		print &text('usave_emaking', "<tt>$merr</tt>"),"<p>\n";
		print "</ul>\n";
		next;
		}

	# Update the user on the server
	print "$text{'usave_update'}<br>\n";
	&remote_foreign_call($serv->{'host'}, "useradmin", "modify_user",
			     \%ouser, $user);
	print "$text{'udel_done'}<p>\n";

	# Make file changes
	if ($in{'servs'} || $host eq $hosts[0]) {
		if ($ouser{'home'} ne $user->{'home'} && $in{'movehome'}) {
			print "$text{'usave_move'}<br>\n";
			&remote_eval($serv->{'host'}, "useradmin",
				"-d '$ouser{'home'}' && !-e '$user->{'home'}' && system(\"mv -f '$ouser{'home'}' '$user->{'home'}'\")");
			print "$text{'udel_done'}<p>\n";
			}
		if ($ouser{'gid'} ne $user->{'gid'}) {
			if ($in{'chgid'} == 1) {
				print "$text{'usave_gid'}<br>\n";
				&remote_foreign_call(
					$serv->{'host'}, "useradmin",
					"recursive_change", $user->{'home'},
					$ouser{'uid'}, $ouser{'gid'}, -1,
					$user->{'gid'});
				print "$text{'udel_done'}<p>\n";
				}
			else {
				print "$text{'usave_gid'}<br>\n";
				&remote_foreign_call(
					$serv->{'host'}, "useradmin",
					"recursive_change", "/",
					$ouser{'uid'}, $ouser{'gid'}, -1,
					$user->{'gid'});
				print "$text{'udel_done'}<p>\n";
				}
			}
		if ($ouser{'uid'} ne $user->{'uid'}) {
			if ($in{'chuid'} == 1) {
				print "$text{'usave_uid'}<br>\n";
				&remote_foreign_call(
					$serv->{'host'}, "useradmin",
					"recursive_change", $user->{'home'},
					$ouser{'uid'}, -1,
					$user->{'uid'}, -1);
				print "$text{'udel_done'}<p>\n";
				}
			else {
				print "$text{'usave_uid'}<br>\n";
				&remote_foreign_call(
					$serv->{'host'}, "useradmin",
					"recursive_change", "/",
					$ouser{'uid'}, -1,
					$user->{'uid'}, -1);
				print "$text{'udel_done'}<p>\n";
				}
			}
		}

	# Rename user in secondary groups
	local @glist;
	if ($in{'sgid_def'} || $user->{'user'} ne $ouser{'user'}) {
		@glist = &remote_foreign_call($serv->{'host'}, "useradmin",
					      "list_groups");
		}
	if ($user->{'user'} ne $ouser{'user'}) {
		print "$text{'usave_rgroups'}<br>\n";
		foreach $group (@glist) {
			local @mems = split(/,/, $group->{'members'});
			local $idx = &indexof($ouser{'user'}, @mems);
			if ($idx >= 0) {
				local %ogroup = %$group;
				$mems[$idx] = $user->{'user'};
				$group->{'members'} = join(",", @mems);
				&remote_foreign_call($serv->{'host'},
					"useradmin", "modify_group",
					\%ogroup, $group);
				}
			}
		print "$text{'udel_done'}<p>\n";
		}

	# Save secondary group information
	if ($in{'sgid_def'} == 1) {
		# Add to some groups
		print "$text{'usave_groups'}<br>\n";
		foreach $g (split(/\s+/, $in{'sgidadd'})) {
			local ($group) = grep { $_->{'group'} eq $g } @glist;
			if ($group) {
				local %ogroup = %$group;
				local @m = &unique(split(/,/,
					$group->{'members'}), $user->{'user'});
				$group->{'members'} = join(",", @m);
				&remote_foreign_call($serv->{'host'},
					"useradmin", "modify_group",
					\%ogroup, $group);
				}
			}
		print "$text{'udel_done'}<p>\n";
		}
	elsif ($in{'sgid_def'} == 2) {
		# Remove from some groups
		print "$text{'udel_groups'}<br>\n";
		foreach $g (split(/\s+/, $in{'sgiddel'})) {
			local ($group) = grep { $_->{'group'} eq $g } @glist;
			if ($group) {
				local %ogroup = %$group;
				local @m = grep { $_ ne $user->{'user'} }
					    split(/,/, $group->{'members'});
				$group->{'members'} = join(",", @m);
				&remote_foreign_call($serv->{'host'},
					"useradmin", "modify_group",
					\%ogroup, $group);
				}
			}
		print "$text{'udel_done'}<p>\n";
		}

	# Run post-change command
	&remote_foreign_call($serv->{'host'}, "useradmin", "made_changes");

	if ($in{'others'}) {
		# Update the user in other modules
		print "$text{'usave_mothers'}<br>\n";
		$user->{'passmode'} = $in{'passmode'};
		if ($in{'passmode'} == 2 && $user->{'pass'} eq $ouser{'pass'}) {
			$user{'passmode'} = 4;
			}
		$user->{'plainpass'} = $in{'pass'} if ($in{'passmode'} == 3);
		&remote_foreign_call($serv->{'host'}, "useradmin",
				     "other_modules", "useradmin_modify_user",
				     $user, \%ouser);
		print "$text{'udel_done'}<p>\n";
		}

	# Update in local list
	$host->{'users'} = \@ulist;
	if (@glist) {
		$host->{'groups'} = \@glist;
		}
	&save_useradmin_host($host);
	print "</ul>\n";
	}
&webmin_log("modify", "user", $user->{'user'}, $user);

&ui_print_footer("", $text{'index_return'});

