#!/usr/local/bin/perl
# save_user.cgi
# Modify or create a webmin user

require './acl-lib.pl';
&foreign_require("webmin", "webmin-lib.pl");
&ReadParse();

# Check for special button clicks, and redirect
if ($in{'but_clone'}) {
	&redirect("edit_user.cgi?clone=".&urlize($in{'old'}));
	exit;
	}
elsif ($in{'but_log'}) {
	&redirect("../webminlog/search.cgi?uall=0&mall=1&tall=1&user=".
		  &urlize($in{'old'}));
	exit;
	}
elsif ($in{'but_switch'}) {
	&redirect("switch.cgi?user=".&urlize($in{'old'}));
	exit;
	}
elsif ($in{'but_delete'}) {
	&redirect("delete_user.cgi?user=".&urlize($in{'old'}));
	exit;
	}

# Get the user object
@ulist = &list_users();
if ($in{'old'}) {
	$in{'name'} = $in{'old'} if (!$access{'rename'});
	&can_edit_user($in{'old'}) || &error($text{'save_euser'});
	foreach $u (@ulist) {
		$old = $u if ($u->{'name'} eq $in{'old'});
		}
	}
else {
	$access{'create'} || &error($text{'save_ecreate'});
	}
&error_setup($text{'save_err'});

# Validate username, and check for a clash
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ && $in{'name'} !~ /^\@/ ||
	&error(&text('save_ename', $in{'name'}));
$in{'name'} eq 'webmin' && &error($text{'save_enamewebmin'});
if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
	foreach $u (@ulist) {
		if ($u->{'name'} eq $in{'name'}) {
			&error(&text('save_edup', $in{'name'}));
			}
		}
	}
!$access{'logouttime'} || $in{'logouttime_def'} ||
	$in{'logouttime'} =~ /^\d+$/ || &error($text{'save_elogouttime'});
!$access{'minsize'} || $in{'minsize_def'} ||
	$in{'minsize'} =~ /^\d+$/ || &error($text{'save_eminsize'});

# Find logged-in webmin user
foreach $u (@ulist) {
	if ($u->{'name'} eq $base_remote_user) {
		$me = $u;
		}
	}

# Find the current group
if ($in{'old'}) {
	foreach $g (&list_groups()) {
		if (&indexof($in{'old'}, @{$g->{'members'}}) >= 0) {
			$oldgroup = $g;
			}
		}
	}

if (&supports_rbac()) {
	# Save RBAC mode
	$user{'rbacdeny'} = $in{'rbacdeny'};
	}

if ($in{'risk'}) {
	# Just store the skill and risk levels
	$user{'skill'} = $in{'skill'};
	$user{'risk'} = $in{'risk'};
	delete($user{'modules'});
	}
else {
	if (defined($in{'group'})) {
		# Check if group is allowed
		if ($access{'gassign'} ne '*') {
			local @gcan = split(/\s+/, $access{'gassign'});
			$in{'group'} && &indexof($in{'group'}, @gcan) >= 0 ||
			  !$in{'group'} && &indexof('_none', @gcan) >= 0 ||
			  $oldgroup && $oldgroup->{'name'} eq $in{'group'} ||
				&error($text{'save_egroup'});
			}

		# Store group membership
		@glist = &list_groups();
		($group) = grep { $_->{'name'} eq $in{'group'} } @glist;
		if ($in{'group'} ne ($oldgroup ? $oldgroup->{'name'} : '')) {
			# Group has changed - update the member lists
			if ($oldgroup) {
				# Take out of old
				$oldgroup->{'members'} =
					[ grep { $_ ne $in{'old'} }
					  @{$oldgroup->{'members'}} ];
				&modify_group($oldgroup->{'name'}, $oldgroup);
				}
			if ($group) {
				# Put into new
				push(@{$group->{'members'}}, $in{'name'});
				&modify_group($in{'group'}, $group);
				}
			}
		elsif ($in{'old'} ne $in{'name'} && $oldgroup && $group) {
			# Name has changed - rename in group
			local $idx = &indexof(
				$in{'old'}, @{$oldgroup->{'members'}});
			$oldgroup->{'members'}->[$idx] = $in{'name'};
			&modify_group($oldgroup->{'name'}, $oldgroup);
			}
		}

	# Store manually selected modules
	@mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
		$access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
				       &list_modules();
	map { $mcan{$_}++ } @mcan;

	@mods = split(/\0/, $in{'mod'});
	foreach $m (@mods) {
		$mcan{$m} || &error(&text('save_emod', $m));
		}
	if ($in{'old'}) {
		# Add modules that this user already has, but were not
		# allowed to be changed or are not available for this OS
		foreach $m (@{$old->{'modules'}}) {
			push(@mods, $m) if (!$mcan{$m});
			}
		}
	if ($base_remote_user eq $in{'old'} &&
	    &indexof("acl", @mods) == -1 &&
	    (!$group || &indexof("acl", @{$group->{'modules'}}) == -1)) {
		&error($text{'save_edeny'});
		}

	if ($oldgroup) {
		# Remove modules from the old group
		@mods = grep { &indexof($_, @{$oldgroup->{'modules'}}) < 0 }
			     @mods;
		}

	if (!$in{'old'} && $access{'perms'}) {
		# Copy .acl files from creator to new user
		&copy_acl_files($me->{'name'}, $in{'name'}, $me->{'modules'});
		}

	if ($group) {
		# Add modules from group to list
		local @ownmods;
		foreach $m (@mods) {
			push(@ownmods, $m)
				if (&indexof($m, @{$group->{'modules'}}) < 0);
			}
		@mods = &unique(@mods, @{$group->{'modules'}});
		$user{'ownmods'} = \@ownmods;

		# Copy ACL files for group
		local $name = $in{'old'} ? $in{'old'} : $in{'name'};
		&copy_group_user_acl_files($in{'group'}, $name,
				      [ @{$group->{'modules'}}, "" ]);
		}
	$user{'modules'} = \@mods;
	delete($user{'skill'});
	delete($user{'risk'});
	}

# Update user object
$salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
$user{'name'} = $in{'name'};
$user{'lang'} = !$access{'lang'} ? $old->{'lang'} :
		$in{'lang_def'} ? undef : $in{'lang'};
if (!$access{'theme'}) {
	$user{'theme'} = $old->{'theme'};
	$user{'overlay'} = $old->{'overlay'};
	}
else {
	$user{'theme'} = $in{'theme_def'} ? undef : $in{'theme'};
	$user{'overlay'} = $in{'overlay_def'} ? undef : $in{'overlay'};
	if ($user{'overlay'} && !$user{'theme'}) {
		&error($text{'save_eoverlay'});
		}
	}
$user{'cert'} = !$access{'chcert'} ? $old->{'cert'} :
		$in{'cert_def'} ? undef : $in{'cert'};
$user{'notabs'} = !$access{'cats'} ? $old->{'notabs'} : $in{'notabs'};
$user{'logouttime'} = !$access{'logouttime'} ? $old->{'logouttime'} :
			$in{'logouttime_def'} ? undef : $in{'logouttime'};
$user{'minsize'} = !$access{'minsize'} ? $old->{'minsize'} :
			$in{'minsize_def'} ? undef : $in{'minsize'};
$user{'nochange'} = !$access{'nochange'} || !defined($in{'nochange'}) ?
			$old->{'nochange'} : $in{'nochange'};
$user{'lastchange'} = $old->{'lastchange'};
$user{'olds'} = $old->{'olds'};
$user{'real'} = $in{'real'} =~ /\S/ ? $in{'real'} : undef;
$raddr = $ENV{'REMOTE_ADDR'};
if ($access{'ips'}) {
	if ($in{'ipmode'}) {
		@hosts = split(/\s+/, $in{"ips"});
		if (!@hosts) { &error($text{'save_enone'}); }
		foreach $h (@hosts) {
			$err = &webmin::valid_allow($h);
			&error($err) if ($err);
			push(@ips, $h);
			}
		}
	if ($in{'ipmode'} == 1) {
		$user{'allow'} = join(" ", @ips);
		if ($old->{'name'} eq $base_remote_user &&
		    !&webmin::ip_match($raddr, @ips)) {
			&error(&text('save_eself', $raddr));
			}
		}
	elsif ($in{'ipmode'} == 2) {
		$user{'deny'} = join(" ", @ips);
		if ($old->{'name'} eq $base_remote_user &&
		    &webmin::ip_match($raddr, @ips)) {
			&error(&text('save_eself', $raddr));
			}
		}
	}
else {
	$user{'allow'} = $old->{'allow'};
	$user{'deny'} = $old->{'deny'};
	}
if ($in{'pass_def'} == 0) {
	# New password
	$in{'pass'} =~ /:/ && &error($text{'save_ecolon'});
	$user{'pass'} = &encrypt_password($in{'pass'});
	$user{'sync'} = 0;
	if (!$in{'temp'}) {
		# Check password quality, unless this is a temp password
		$perr = &check_password_restrictions($in{'name'}, $in{'pass'});
		$perr && &error(&text('save_epass', $perr));
		}
	}
elsif ($in{'pass_def'} == 1) {
	# No change in password
	$user{'pass'} = $in{'oldpass'};
	$user{'sync'} = 0;
	}
elsif ($in{'pass_def'} == 3) {
	# Unix authentication
	$user{'pass'} = 'x';
	$user{'sync'} = 0;
	}
elsif ($in{'pass_def'} == 4) {
	# Account is locked
	$user{'pass'} = '*LK*';
	$user{'sync'} = 0;
	}
elsif ($in{'pass_def'} == 5) {
	# External authentcation
	$user{'pass'} = 'e';
	$user{'sync'} = 0;
	}
else {
	# Password synchronization (deprecated)
	&foreign_check("useradmin") || &error($text{'save_eos'});
	&foreign_require("useradmin", "user-lib.pl");
	foreach $uu (&foreign_call("useradmin", "list_users")) {
		$user{'pass'} = $uu->{'pass'}
			if ($uu->{'user'} eq $in{'name'});
		}
	defined($user{'pass'}) ||
		&error(&text('save_eunix', $in{'name'}));
	$user{'sync'} = 1;
	}

# Update allowed days and hours
if ($access{'times'}) {
	# Save the allowed days
	if (!$in{'days_def'}) {
		@days = split(/\0/, $in{'days'});
		@days || &error($text{'save_edays'});
		$user{'days'} = join(",", @days);
		}
	if (!$in{'hours_def'}) {
		foreach $t ('from', 'to') {
			$h = $in{'hours_h'.$t};
			$m = $in{'hours_m'.$t};
			$h =~ /^\d+$/ && $h >= 0 &&
			  $h < 24 || &error($text{'save_ehours'});
			$m =~ /^\d+$/ && $m >= 0 &&
			  $m < 60 || &error($text{'save_ehours'});
			$user{'hours'.$t} = "$h.$m";
			$mins{$t} = $h*60+$m;
			}
		$mins{'from'} < $mins{'to'} || &error($text{'save_ehours2'});
		}
	}
else {
	$user{'days'} = $old->{'days'};
	$user{'hoursfrom'} = $old->{'hoursfrom'};
	$user{'hoursto'} = $old->{'hoursto'};
	}

# Check for temporary password lock
if (!$in{'lock'} && $user{'pass'} =~ /^\!(.*)$/) {
	$user{'pass'} = $1;
	}
elsif ($in{'lock'} && $user{'pass'} !~ /^\!/ && $in{'pass_def'} <= 1) {
	$user{'pass'} = "!".$user{'pass'};
	}

# Check for force change
$user{'temppass'} = $in{'temp'};
if ($in{'temp'}) {
	&get_miniserv_config(\%miniserv);
	$miniserv{'passwd_mode'} == 2 ||
		&error(&text('save_etemp', '../webmin/edit_session.cgi'));
	}

if ($in{'old'}) {
	# update user and all ACLs
	&modify_user($in{'old'}, \%user);
	foreach $u (&list_users()) {
		%uaccess = &get_module_acl($u->{'name'});
		local @au = split(/\s+/, $uaccess{'users'});
		local $idx = &indexof($in{'old'}, @au);
		if ($idx != -1) {
			$au[$idx] = $in{'name'};
			$uaccess{'users'} = join(" ", @au);
			&save_module_acl(\%uaccess, $u->{'name'});
			}
		}
	}
else {
	# create and add to access list
	&create_user(\%user, $in{'clone'});
	if ($access{'users'} ne '*') {
		$access{'users'} .= " ".$in{'name'};
		&save_module_acl(\%access);
		}
	#%aclacl = &get_module_acl();
	#&save_module_acl(\%aclacl, $in{'name'});
	}

if ($in{'old'} && $in{'acl_security_form'} && !$group) {
	# Update user's global ACL
	&foreign_require("", "acl_security.pl");
	&foreign_call("", "acl_security_save", \%uaccess, \%in);
	$aclfile = "$config_directory/$in{'name'}.acl";
	&lock_file($aclfile);
	&write_file($aclfile, \%uaccess);
	chmod(0640, $aclfile);
	&unlock_file($aclfile);
	}

# Log the event
delete($in{'pass'});
delete($in{'oldpass'});
if ($in{'old'}) {
	&webmin_log("modify", "user", $in{'old'}, \%in);
	}
else {
	&webmin_log("create", "user", $user{'name'}, \%in);
	}
&reload_miniserv();
&redirect("");

