#!/usr/local/bin/perl
# save_user.cgi
# Saves or creates a new user. If the changes require moving of the user's
# home directory or changing file ownerships, do that as well

require './user-lib.pl';
use Time::Local;
&error_setup($text{'usave_err'});
&ReadParse();

# Check for buttons at end of user form, redirect if needed
if ($in{'list'}) {
	&redirect("list_logins.cgi?username=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'mailboxes'}) {
	&redirect("../mailboxes/list_mail.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'switch'}) {
	&redirect("../usermin/switch.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'delete'}) {
	&redirect("delete_user.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'clone'}) {
	&redirect("edit_user.cgi?clone=".&urlize($in{'old'}));
	return;
	}

# Build list of used UIDs and GIDs
&build_user_used(\%used);
&build_group_used(\%used) if ($config{'new_user_gid'});
&build_group_used(\%gused);

# Strip out \n characters in inputs
$in{'real'} =~ s/\r|\n//g;
$in{'user'} =~ s/\r|\n//g;
$in{'user'} =~ s/\0.*$//;	# some people reports \0 in usernames!
$in{'pass'} =~ s/\r|\n//g;
$in{'encpass'} =~ s/\r|\n//g;
$in{'home'} =~ s/\r|\n//g;
$in{'gid'} =~ s/\r|\n//g;
$in{'uid'} =~ s/\r|\n//g;
$in{'uid'} = int($in{'uid'});
$in{'othersh'} =~ s/\r|\n//g;
$in{'sshkey'} =~ s/\r|\n//g;

# Validate username
$user{'user'} = $in{'user'};
$in{'user'} =~ /^[^:\t]+$/ ||
	&error(&text('usave_ebadname', $in{'user'}));
$err = &check_username_restrictions($in{'user'});
&error($err) if ($err);

&lock_user_files();
@ulist = &list_users();
@glist = &list_groups();
if ($in{'old'} ne "") {
	# Get old user info
	($ouser_hash) = grep { $_->{'user'} eq $in{'old'} } @ulist;
	$ouser_hash || &error($text{'uedit_egone'});
	%ouser = %$ouser_hash;
	if (!$access{'urename'} && $ouser{'user'} ne $user{'user'}) {
		&error($text{'usave_erename'});
		}
	$user{'olduser'} = $ouser{'user'};
	if ($user{'user'} ne $ouser{'user'}) {
		foreach $ou (@ulist) {
			&error(&text('usave_einuse', $in{'user'}))
				if ($ou->{'user'} eq $in{'user'});
			}
		$access{'uedit_mode'} == 2 && &error($text{'usave_erename'});
		$renaming = 1;
		}
	&can_edit_user(\%access, \%ouser) || &error($text{'usave_eedit'});
	}
else {
	# check new user details
	$access{'ucreate'} || &error($text{'usave_ecreate'});
	foreach $ou (@ulist) {
		&error(&text('usave_einuse', $in{'user'}))
			if ($ou->{'user'} eq $in{'user'});
		}
	}
if (($in{'old'} eq '' || $user{'user'} ne $ouser{'user'}) &&
    $config{'alias_check'} && &foreign_check("sendmail")) {
	# Check if the new username conflicts with a sendmail alias
	&foreign_require("sendmail", "sendmail-lib.pl");
	&foreign_require("sendmail", "aliases-lib.pl");
	local $conf = &foreign_call("sendmail", "get_sendmailcf");
	local $afiles = &foreign_call("sendmail", "aliases_file", $conf);
	foreach $a (&foreign_call("sendmail", "list_aliases", $afiles)) {
		&error(&text('usave_einuse_a', $in{'user'}))
			if ($a->{'name'} eq $in{'user'});
		}
	}

# Validate and store basic inputs
if (!$in{'uid_def'} || $in{'old'} ne '') {
	# Only do UID checks if not automatic
	$in{'uid'} =~ /^\-?[0-9]+$/ || &error(&text('usave_euid', $in{'uid'}));
	if (!%ouser || $ouser{'uid'} != $in{'uid'}) {
		!$access{'lowuid'} || $in{'uid'} >= $access{'lowuid'} ||
			&error(&text('usave_elowuid', $access{'lowuid'}));
		!$access{'hiuid'} || $in{'uid'} <= $access{'hiuid'} ||
			&error(&text('usave_ehiuid', $access{'hiuid'}));
		}
	if (!$access{'uuid'} && %ouser && $ouser{'uid'} != $in{'uid'}) {
		&error($text{'usave_euuid'});
		}
	if (!$access{'umultiple'}) {
		foreach $ou (@ulist) {
			if ($ou->{'uid'} == $in{'uid'} &&
			    $ou->{'user'} ne $ouser{'user'}) {
				&error(&text('usave_euidused',
					     $ou->{'user'}, $in{'uid'}));
				}
			}
		}
	}
elsif ( $in{'uid_def'} eq '1' ) {
	# Can assign UID here
	$in{'uid'} = int($config{'base_uid'} > $access{'lowuid'} ?
			 $config{'base_uid'} : $access{'lowuid'});
	while($used{$in{'uid'}}) {
		$in{'uid'}++;
		}
	if ($access{'hiuid'} && $in{'uid'} > $access{'hiuid'}) {
		# Out of UIDs!
		&error($text{'usave_ealluid'});
		}
	}

elsif ( $in{'uid_def'} eq '2' ) {
	# Can calculate UID here
        if ( $config{'uid_calc'} ) {
            $in{'uid'} = &mkuid($in{'user'});
        } else {
            $in{'uid'} = &berkeley_cksum($in{'user'});
        }
        &error("Unable to calculate UID, invalid user name specified") if ( $in{'uid'} lt 0 );
	while($used{$in{'uid'}}) {
		$in{'uid'}++;
		}
	if ($access{'hiuid'} && $in{'uid'} > $access{'hiuid'}) {
		# Out of UIDs!
		&error($text{'usave_ealluid'});
		}
	}

$in{'real'} =~ /^[^:]*$/ || &error(&text('usave_ereal', $in{'real'}));
if ($in{'shell'} eq "*") { $in{'shell'} = $in{'othersh'}; }
if ($access{'shells'} ne "*") {
	if (&indexof($in{'shell'}, split(/\s+/, $access{'shells'})) < 0 &&
	    (!%ouser || $in{'shell'} ne $ouser{'shell'})) {
		&error(&text('usave_eshell', $in{'shell'}));
		}
	}
$user{'uid'} = $in{'uid'};
if ($in{'old'} ne "" || !$in{'gidmode'}) {
	# Selecting existing group
	$user{'gid'} = &my_getgrnam($in{'gid'});
	if ($user{'gid'} eq "") { &error(&text('usave_egid', $in{'gid'})); }
	$grp = $in{'gid'};
	}
else {
	# Creating a new group
	$access{'gcreate'} || &error($text{'usave_egcreate'});
	if ($in{'gidmode'} == 2) {
		# New group has same name as user
		$in{'newgid'} = $in{'user'};
		}
	else {
		# New group has arbitrary name
		$in{'newgid'} =~ /^[^: \t]+$/ ||
			&error(&text('gsave_ebadname', $in{'newgid'}));
		}
	foreach $og (@glist) {
		&error(&text('usave_einuseg', $in{'newgid'}))
			if ($og->{'group'} eq $in{'newgid'});
		}
	$grp = $in{'newgid'};
	}
if ($config{'extra_real'}) {
	$in{'real'} =~ /^[^:,]*$/ || &error(&text('usave_ereal', $in{'real'}));
	$in{'office'} =~ /^[^:,]*$/ || &error($text{'usave_eoffice'});
	$in{'workph'} =~ /^[^:,]*$/ || &error($text{'usave_eworkph'});
	$in{'homeph'} =~ /^[^:,]*$/ || &error($text{'usave_ehomeph'});
	$user{'real'} = join(",", $in{'real'}, $in{'office'}, $in{'workph'},
				  $in{'homeph'});
	$user{'real'} .= ",$in{'extra'}" if ($in{'extra'});
	}
else {
	$user{'real'} = $in{'real'};
	}

if ($config{'real_base'} &&
    $user{'home'} eq &auto_home_dir($config{'home_base'},
				    $ouser{'user'}, $grp)) {
	# Work out old real home
	$old_real_home = &auto_home_dir($config{'real_base'},
					$ouser{'user'}, $grp);
	}
if ($access{'autohome'}) {
	# Home directory is forced to automatic
	if ($in{'new'} || $ouser{'user'} ne $user{'user'}) {
		$user{'home'} = &auto_home_dir($access{'home'}, $in{'user'},
					       $grp);
		$real_home = &auto_home_dir($config{'real_base'}, $in{'user'},
					    $grp) if ($config{'real_base'});
		}
	else {
		$user{'home'} = $ouser{'home'};
		}
	}
elsif ($config{'home_base'} && $in{'home_base'}) {
	# Automatic home directory option chosen
	$user{'home'} = &auto_home_dir($config{'home_base'}, $in{'user'},
				       $grp);
	$real_home = &auto_home_dir($config{'real_base'}, $in{'user'},
				    $grp) if ($config{'real_base'});
	}
else {
	# Manual home directory chosen
	if ($in{'home'} =~ /\/$/ && $in{'home'} ne '/') {
		&error(&text('usave_ehomeslash', $in{'home'}));
		}
	$user{'home'} = $in{'home'};
	}
$real_home ||= $user{'home'};
if (!$access{'autohome'}) {
	$user{'home'} =~ /^\// || &error(&text('usave_ehome', $in{'home'}));
	if (!&is_under_directory($access{'home'}, $user{'home'})) {
		&error(&text('usave_ehomepath', $user{'home'}));
		}
	}
$user{'shell'} = $in{'shell'};
@sgnames = $config{'secmode'} == 2 ? &split_quoted_string($in{'sgid'})
                                   : split(/\r?\n/, $in{'sgid'});
foreach $gname (@sgnames) {
	$ingroup{$gname}++;
	$gid = &my_getgrnam($gname);
	defined($gid) || &error(&text('usave_esgname', $gname));
	push(@sgids, $gid);
	}

if ($access{'ugroups'} ne "*") {
	if ($in{'old'} ne "") {
		# existing users can only be added to or removed from
		# allowed groups
		if ($ouser{'gid'} != $user{'gid'}) {
			&can_use_group(\%access, $in{'gid'}) ||
				&error(&text('usave_eprimary', $in{'gid'}));
			local $og = &my_getgrgid($ouser{'gid'});
			&can_use_group(\%access, $og) ||
				&error(&text('usave_eprimaryr', $og));
			}
		foreach $g (@glist) {
			local @mems = split(/,/ , $g->{'members'});
			local $idx = &indexof($ouser{'user'}, @mems);
			if ($ingroup{$g->{'group'}} && $idx<0 &&
			    !&can_use_group(\%access, $g->{'group'})) {
				&error(&text('usave_esecondary',
					     $g->{'group'}));
				}
			elsif (!$ingroup{$g->{'group'}} && $idx>=0 &&
			       !&can_use_group(\%access, $g->{'group'})) {
				&error(&text('usave_esecondaryr',
					     $g->{'group'}));
				}
			}
		}
	elsif (!$in{'gidmode'}) {
		# new users can only be added to allowed groups
		# This is skipped if we are creating a new group for
		# new users
		&can_use_group(\%access, $in{'gid'}) ||
			&error(&text('usave_eprimary', $in{'gid'}));
		foreach $gname (@sgnames) {
			&can_use_group(\%access, $gname) ||
				&error(&text('usave_esecondary', $group));
			}
		}
	}

# Store password input
if ($in{'passmode'} == 0) {
	# Password is blank
	if (!$config{'empty_mode'}) {
		local $err = &check_password_restrictions("", $user{'user'},
				$in{'old'} eq '' ? 'none' : \%ouser);
		&error($err) if ($err);
		}
	$user{'pass'} = "";
	}
elsif ($in{'passmode'} == 1) {
	# Password is locked
	$user{'pass'} = $config{'lock_string'};
	}
elsif ($in{'passmode'} == 2) {
	# Specific encrypted password entered, or possibly no change
	$user{'pass'} = $in{'encpass'};
	}
elsif ($in{'passmode'} == 3) {
	# Normal password entered - check restrictions
	local $err = &check_password_restrictions($in{'pass'}, $user{'user'},
				$in{'old'} eq '' ? 'none' : \%ouser);
	&error($err) if ($err);
	$user{'pass'} = &encrypt_password($in{'pass'});
	}
if (&supports_temporary_disable() &&
    $in{'disable'} && ($in{'passmode'} == 2 || $in{'passmode'} == 3)) {
	$user{'pass'} = $disable_string.$user{'pass'};
	}

$pft = &passfiles_type();
if ($pft == 2 || $pft == 5) {
	if ($access{'peopt'}) {
		# Validate shadow-password inputs
		$in{'min'} =~ /^\-?[0-9]*$/ ||
			&error(&text('usave_emin', $in{'min'}));
		$in{'max'} =~ /^\-?[0-9]*$/ ||
			&error(&text('usave_emax', $in{'max'}));
		$user{'min'} = $in{'min'};
		$user{'max'} = $in{'max'};
		if ($pft == 2) {
			if ($in{'expired'} ne "" && $in{'expirem'} ne ""
			    && $in{'expirey'} ne "") {
				eval { $expire = timelocal(0, 0, 12,
							$in{'expired'},
						   	$in{'expirem'}-1,
							$in{'expirey'}-1900); };
				if ($@) { &error($text{'usave_eexpire'}); }
				$expire = int($expire / (60*60*24));
				}
			else { $expire = ""; }
			$user{'expire'} = $expire;
			$in{'warn'} =~ /^\-?[0-9]*$/ ||
			    &error(&text('usave_ewarn', $in{'warn'}));
			$in{'inactive'} =~ /^\-?[0-9]*$/ ||
			    &error(&text('usave_einactive', $in{'inactive'}));
			$user{'warn'} = $in{'warn'};
			$user{'inactive'} = $in{'inactive'};
			}
		}
	else {
		$user{'expire'} = $ouser{'expire'};
		$user{'min'} = $ouser{'min'};
		$user{'max'} = $ouser{'max'};
		if ($pft == 2) {
			$user{'warn'} = $ouser{'warn'};
			$user{'inactive'} = $ouser{'inactive'};
			}
		}
	$daynow = int(time() / (60*60*24));
	$user{'change'} = $in{'forcechange'} ? 0 :
			  $pft == 5 && $in{'ask'} ? 0 :
			  !%ouser ? $daynow :
			  $in{'passmode'} == 3 ? $daynow :
			  $in{'passmode'} == 2 &&
			  $user{'pass'} ne $ouser{'pass'} ? $daynow :
							    $ouser{'change'};
	}
elsif ($pft == 1 || $pft == 6) {
	if ($access{'peopt'}) {
		# Validate BSD-password inputs
		if ($in{'expired'} ne "" && $in{'expirem'} ne ""
		    && $in{'expirey'} ne "") {
			eval { $expire = timelocal(59, $in{'expiremi'},
						   $in{'expireh'},
						   $in{'expired'},
						   $in{'expirem'}-1,
						   $in{'expirey'}-1900); };
			if ($@) { &error($text{'usave_eexpire'}); }
			}
		else { $expire = ""; }
		if ($in{'changed'} ne "" && $in{'changem'} ne ""
		    && $in{'changey'} ne "") {
			eval { $change = timelocal(59, $in{'changemi'},
						   $in{'changeh'},
						   $in{'changed'},
						   $in{'changem'}-1,
						   $in{'changey'}-1900); };
			if ($@) { &error($text{'usave_echange'}); }
			}
		else { $change = ""; }
		$in{'class'} =~ /^([^: ]*)$/ ||
			&error(&text('usave_eclass', $in{'class'}));
		$user{'expire'} = $expire;
		$user{'change'} = $change;
		$user{'class'} = $in{'class'};
		}
	else {
		$user{'expire'} = $ouser{'expire'};
		$user{'change'} = $ouser{'change'};
		$user{'class'} = $ouser{'class'};
		}
	}
elsif ($pft == 4) {
	# Validate AIX-style password inputs
	if ($in{'expire_def'} == 1) {
		# System default expiry date
		$expire = undef;
		}
	elsif ($in{'expire_def'} == 2) {
		# Never expires
		$expire = "0";
		}
	else {
		# Add a leading zero if only 1 digit long
		$in{'expirem'} =~ /^\d+$/ && $in{'expired'} =~ /^\d+$/ &&
		   $in{'expireh'} =~ /^\d+$/ && $in{'expiremi'} =~ /^\d+$/ &&
		   $in{'expirey'} =~ /^\d+$/ || &error($text{'usave_eexpire'});
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
	if ($access{'peopt'}) {
		$user{'admin'} = $in{'flags'} =~ /admin/;
		$user{'admchg'} = $in{'flags'} =~ /admchg/;
		$user{'nocheck'} = $in{'flags'} =~ /nocheck/;
		$user{'expire'} = $expire;
		$user{'min'} = $in{'min_def'} ? undef : $in{'min'};
		$user{'max'} = $in{'max_def'} ? undef : $in{'max'};
		$user{'warn'} = $in{'warn_def'} ? undef : $in{'warn'};
		}
	else {
		$user{'admin'} = $ouser{'admin'};
		$user{'admchg'} = $ouser{'admchg'};
		$user{'nocheck'} = $ouser{'nocheck'};
		$user{'expire'} = $ouser{'expire'};
		$user{'min'} = $ouser{'min'};
		$user{'max'} = $ouser{'max'};
		$user{'warn'} = $ouser{'warn'};
		}
	$user{'change'} = !%ouser ? time() :
			  $in{'passmode'} == 3 ? time() :
			  $user{'pass'} ne $ouser{'pass'} ? time() :
							    $ouser{'change'};
	}

if (%ouser) {
	# We are changing an existing user
	if ($ouser{'uid'} != $user{'uid'}) {
		$changing_uid = 1;
		}
	if ($ouser{'gid'} != $user{'gid'}) {
		$changing_gid = 1;
		}
	if ($ouser{'home'} ne $user{'home'}) {
		$changing_homedir = 1;
		}
	$in{'old'} = $ouser{'user'};

	# Force defaults for save options if necessary
	$in{'movehome'} = !$access{'movehome'} if ($access{'movehome'} != 1);
	$in{'chuid'} = !$access{'chuid'} if ($access{'chuid'} != 1);
	$in{'chgid'} = !$access{'chgid'} if ($access{'chgid'} != 1);
	$in{'others'} = !$access{'mothers'} if ($access{'mothers'} != 1);

	# Run the pre-change command
	&set_user_envs(\%user, 'MODIFY_USER',
		$in{'passmode'} == 3 ? $in{'pass'} : "", \@sgids, $ouser);
	$merr = &making_changes();
	&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

	# Move the home directory if needed
	if ($changing_homedir && $in{'movehome'}) {
		&error($text{'usave_efromroot'}) if ($ouser{'home'} eq "/");
		&error($text{'usave_etoroot'}) if ($user{'home'} eq "/");
		if (-d $ouser{'home'} && !-e $user{'home'}) {
			# Move home directory if the old one exists and
			# the new one does not.
			if ($real_home && $old_real_home) {
				# Move real home dir
				$out = &backquote_logged(
					"mv ".quotemeta($old_real_home)." ".
					      quotemeta($real_home)." 2>&1");
				}
			else {
				$out = &backquote_logged(
					"mv ".quotemeta($ouser{'home'})." ".
					      quotemeta($user{'home'})." 2>&1");
				}
			if ($?) { &error(&text('usave_emove', $out)); }
			}
		}

	# Change GID on files if needed
	if ($changing_gid && $in{'chgid'}) {
		if ($in{'chgid'} == 1) {
			&recursive_change($user{'home'}, $ouser{'uid'},
					  $ouser{'gid'}, -1, $user{'gid'});
			}
		else {
			&recursive_change("/", $ouser{'uid'},
					  $ouser{'gid'}, -1, $user{'gid'});
			}
		}

	# Change UID on files if needed
	if ($changing_uid && $in{'chuid'}) {
		if ($in{'chuid'} == 1) {
			&recursive_change($user{'home'}, $ouser{'uid'},
					  -1, $user{'uid'}, -1);
			}
		else {
			&recursive_change("/", $ouser{'uid'},
					  -1, $user{'uid'}, -1);
			}
		}

	# Update user details
	$user{'passmode'} = $in{'passmode'};
	if ($in{'passmode'} == 2 && $user{'pass'} eq $ouser{'pass'}) {
		# not changing password
		$user{'passmode'} = 4;
		}
	$user{'plainpass'} = $in{'pass'} if ($in{'passmode'} == 3);
	&modify_user(\%ouser, \%user);

	# Rename group if needed and if possible
	if ($user{'user'} ne $ouser{'user'} &&
	    $user{'gid'} == $ouser{'gid'} &&
	    $in{'grename'}) {
		($group) = grep { $_->{'gid'} == $user{'gid'} } &list_groups();
		if ($group->{'group'} eq $ouser{'user'} &&
		    &can_edit_group(\%access, $group)) {
			# Do the rename
			$ogroup = { %$group };
			$group->{'group'} = $user{'user'};
			&modify_group($ogroup, $group);
			}
		}
	}
else {
	# Force defaults for save options if necessary
	$in{'makehome'} = !$access{'makehome'} if ($access{'makehome'} != 1);
	$in{'copy_files'} = !$access{'copy'} if ($access{'copy'} != 1 &&
						 $config{'user_files'} =~ /\S/);
	$in{'others'} = !$access{'cothers'} if ($access{'cothers'} != 1);

	# Run the pre-change command
	&set_user_envs(\%user, 'CREATE_USER',
		       $in{'passmode'} == 3 ? $in{'pass'} : "", \@sgids);
	$merr = &making_changes();
	&error(&text('usave_emaking', "<tt>$merr</tt>")) if (defined($merr));

	# Create the home directory
	if ($in{'makehome'}) {
		&create_home_directory(\%user, $real_home);
		$made_home = 1;
		}

	if ($in{'gidmode'}) {
		# New group for the new user ..
		if ($config{'new_user_gid'}) {
			# gid is the same as the uid
			$newgid = $user{'uid'};
			}
		else {
			# find the first free GID above the base
			$newgid = int($config{'base_gid'} > $access{'lowgid'} ?
				      $config{'base_gid'} : $access{'lowgid'});
			while($gused{$newgid}) {
				$newgid++;
				}
			}

		# create a new group for this user
		$created_group = $group{'group'} = $in{'newgid'};
		$user{'gid'} = $group{'gid'} = $newgid;
		&create_group(\%group);
		$created_group = \%group;
		}

	if ($made_home) {
		&set_ownership_permissions($user{'uid'}, $user{'gid'},
					   undef, $real_home) ||
			&error(&text('usave_echown', $!));
		}

	# Save user details
	$user{'passmode'} = $in{'passmode'};
	$user{'plainpass'} = $in{'pass'} if ($in{'passmode'} == 3);
	&create_user(\%user);

	# Copy files into user's directory
	if ($in{'copy_files'} && $in{'makehome'}) {
		local $uf = &get_skel_directory(\%user, $in{'gid'});
		&copy_skel_files($uf, $real_home, $user{'uid'}, $user{'gid'});
		}

	# Grant access from the given SSH key
	if ($in{'sshkey'} =~ /\S/ && -d $real_home) {
		my $sshdir = $real_home."/.ssh";
		if (!-e $sshdir) {
			&make_dir($sshdir, 0700);
			&set_ownership_permissions(
				$user{'uid'}, $user{'gid'}, 0700, $sshdir);
			}
		my $sshfile = $sshdir."/authorized_keys";
		my $ex = -e $sshfile;
		&open_tempfile(SSHFILE, ">>$sshfile");
		&print_tempfile(SSHFILE, $in{'sshkey'},"\n");
		&close_tempfile(SSHFILE);
		if (!$ex) {
			&set_ownership_permissions(
				$user{'uid'}, $user{'gid'}, 0600, $sshfile);
			}
		}
	}

if ($config{'secmode'} != 1) {
	# Update secondary groups
	foreach $g (@glist) {
		@mems = split(/,/ , $g->{'members'});
		if ($renaming) {
			$idx = &indexof($ouser{'user'}, @mems);
			if ($ingroup{$g->{'group'}} && $idx<0) {
				# Need to add to the group
				push(@mems, $user{'user'});
				}
			elsif (!$ingroup{$g->{'group'}} && $idx>=0) {
				# Need to remove from the group
				splice(@mems, $idx, 1);
				}
			elsif ($idx >= 0) {
				# Need to rename in group
				$mems[$idx] = $user{'user'};
				}
			else { next; }
			}
		else {
			$idx = &indexof($user{'user'}, @mems);
			if ($ingroup{$g->{'group'}} && $idx<0) {
				# Need to add to the group
				push(@mems, $user{'user'});
				}
			elsif (!$ingroup{$g->{'group'}} && $idx>=0) {
				# Need to remove from the group
				splice(@mems, $idx, 1);
				}
			else { next; }
			}
		%newg = %$g;
		$newg{'members'} = join(',', @mems);
		&modify_group($g, \%newg);
		}
	}
&unlock_user_files();
&made_changes();

# Run other modules' scripts
if ($in{'others'}) {
	$error_must_die = 1;
	eval {
		if (%ouser) {
			&other_modules("useradmin_modify_user", \%user,\%ouser);
			}
		else {
			&other_modules("useradmin_create_user", \%user);
			}
		if ($created_group) {
			&other_modules("useradmin_create_group",
				       $created_group);
			}
		};
	$error_must_die = 0;
	$others_err = $@;
	}

delete($in{'pass'});
delete($in{'encpass'});
&webmin_log(%ouser ? 'modify' : 'create', 'user', $in{'user'}, \%in);
&webmin_log('create', 'group', $created_group->{'group'}, \%in)
	if ($created_group);

# Bounce back to the list, if everything worked
&error(&text('usave_eothers', $others_err)) if ($others_err);
&redirect("index.cgi?mode=users");


