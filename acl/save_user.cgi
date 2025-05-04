#!/usr/local/bin/perl
# save_user.cgi
# Modify or create a webmin user

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $config_directory, $base_remote_user);
&foreign_require("webmin", "webmin-lib.pl");
&ReadParse();

# Check for special button clicks, and redirect
if ($in{'but_clone'}) {
	&redirect("edit_user.cgi?clone=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'but_log'}) {
	&redirect("../webminlog/search.cgi?uall=0&mall=1&tall=1&user=".
		  &urlize($in{'old'}));
	return;
	}
elsif ($in{'but_switch'}) {
	&redirect("switch.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'but_delete'}) {
	&redirect("delete_user.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'twofactor'}) {
	&redirect("twofactor_form.cgi?user=".&urlize($in{'old'}));
	return;
	}
elsif ($in{'but_forgot'}) {
	&redirect("forgot_form.cgi?user=".&urlize($in{'old'}));
	return;
	}

# Get the user object
my (%user, $old);
if ($in{'old'}) {
	%user = ( );
	$in{'name'} = $in{'old'} if (!$access{'rename'});
	&can_edit_user($in{'old'}) || &error($text{'save_euser'});
	$old = &get_user($in{'old'});
	$old || &error($text{'edit_egone'});
	$user{'proto'} = $old->{'proto'};
	$user{'id'} = $old->{'id'};
	$user{'twofactor_provider'} = $old->{'twofactor_provider'};
	$user{'twofactor_id'} = $old->{'twofactor_id'};
	}
else {
	$access{'create'} || &error($text{'save_ecreate'});
	}
&error_setup($text{'save_err'});

# Validate username, and check for a clash
$in{'name'} =~ /^[A-z0-9\-\_\.\@]+$/ && $in{'name'} !~ /^\@/ ||
	&error(&text('save_ename', &html_escape($in{'name'})));
$in{'name'} eq 'webmin' && &error($text{'save_enamewebmin'});
if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
	my $clash = &get_user($in{'name'});
	$clash && &error(&text('save_edup', &html_escape($in{'name'})));
	}
!$access{'logouttime'} || $in{'logouttime_def'} ||
	$in{'logouttime'} =~ /^\d+$/ || &error($text{'save_elogouttime'});
!$access{'minsize'} || $in{'minsize_def'} ||
	$in{'minsize'} =~ /^\d+$/ || &error($text{'save_eminsize'});
if ($in{'safe'} && !$in{'unsafe'}) {
	getpwnam($in{'name'}) ||
		&error(&text('save_eunixname', &html_escape($in{'name'})));
	}

# Validate password
if ($in{'pass_def'} == 0) {
	$in{'pass'} =~ /:/ && &error($text{'save_ecolon'});
	if (!$in{'temp'}) {
		# Check password quality, unless this is a temp password
		my $perr = &check_password_restrictions($in{'name'},
							$in{'pass'});
		$perr && &error(&text('save_epass', $perr));
		}
	}

# Validate force change
if ($in{'temp'}) {
	my %miniserv;
	&get_miniserv_config(\%miniserv);
	$miniserv{'passwd_mode'} == 2 ||
		&error(&text('save_etemp', '../webmin/edit_session.cgi'));
	}


# Find logged-in webmin user
my @ulist = &list_users();
my $me;
foreach my $u (@ulist) {
	if ($u->{'name'} eq $base_remote_user) {
		$me = $u;
		}
	}

# Find the current group
my $oldgroup = $in{'old'} ? &get_users_group($in{'old'}) : undef;

if (&supports_rbac()) {
	# Save RBAC mode
	$user{'rbacdeny'} = $in{'rbacdeny'};
	}

my $newgroup;
if (defined($in{'group'})) {
	# Check if group is allowed
	if ($access{'gassign'} ne '*') {
		my @gcan = split(/\s+/, $access{'gassign'});
		$in{'group'} && &indexof($in{'group'}, @gcan) >= 0 ||
		  !$in{'group'} && &indexof('_none', @gcan) >= 0 ||
		  $oldgroup && $oldgroup->{'name'} eq $in{'group'} ||
			&error($text{'save_egroup'});
		}

	# Store group membership
	$newgroup = &get_group($in{'group'});
	if ($in{'group'} ne ($oldgroup ? $oldgroup->{'name'} : '')) {
		# Group has changed - update the member lists
		if ($oldgroup) {
			# Take out of old
			$oldgroup->{'members'} =
				[ grep { $_ ne $in{'old'} }
				  @{$oldgroup->{'members'}} ];
			&modify_group($oldgroup->{'name'}, $oldgroup);
			}
		if ($newgroup) {
			# Put into new
			push(@{$newgroup->{'members'}}, $in{'name'});
			&modify_group($in{'group'}, $newgroup);
			}
		}
	elsif ($in{'old'} ne $in{'name'} && $oldgroup && $newgroup) {
		# Name has changed - rename in group
		my $idx = &indexof(
			$in{'old'}, @{$oldgroup->{'members'}});
		$oldgroup->{'members'}->[$idx] = $in{'name'};
		&modify_group($oldgroup->{'name'}, $oldgroup);
		}
	}

# Store manually selected modules
my @mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
	   $access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
				  &list_modules();
my %mcan = map { $_, 1 } @mcan;

my @mods = split(/\0/, $in{'mod'});
foreach my $m (@mods) {
	$mcan{$m} || &error(&text('save_emod', $m));
	}
if ($in{'old'}) {
	# Add modules that this user already has, but were not
	# allowed to be changed or are not available for this OS
	foreach my $m (@{$old->{'modules'}}) {
		push(@mods, $m) if (!$mcan{$m});
		}
	}

if ($oldgroup) {
	# Remove modules from the old group
	@mods = grep { &indexof($_, @{$oldgroup->{'modules'}}) < 0 }
		     @mods;
	}

if ($base_remote_user eq $in{'old'} &&
    &indexof("acl", @mods) == -1 &&
    (!$newgroup || &indexof("acl", @{$newgroup->{'modules'}}) == -1)) {
	&error($text{'save_edeny'});
	}

if (!$in{'old'} && $access{'perms'}) {
	# Copy .acl files from creator to new user
	&copy_acl_files($me->{'name'}, $in{'name'}, $me->{'modules'});
	}

if ($newgroup) {
	# Add modules from group to list
	my @ownmods;
	foreach my $m (@mods) {
		push(@ownmods, $m)
			if (&indexof($m, @{$newgroup->{'modules'}}) < 0);
		}
	@mods = &unique(@mods, @{$newgroup->{'modules'}});
	$user{'ownmods'} = \@ownmods;

	# Copy ACL files for group
	my $name = $in{'old'} ? $in{'old'} : $in{'name'};
	&copy_group_user_acl_files($in{'group'}, $name,
			      [ @{$newgroup->{'modules'}}, "" ]);
	}
$user{'modules'} = \@mods;

# Update user object
my $salt = chr(int(rand(26))+65).chr(int(rand(26))+65);
$user{'name'} = $in{'name'};
$user{'lang'} = !$access{'lang'} ? $old->{'lang'} :
		$in{'lang_def'} ? undef : $in{'lang'};
$user{'locale'} = !$access{'locale'} ? $old->{'locale'} :
		$in{'locale_def'} ? undef : $in{'locale'};
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
$in{'email'} =~ /:/ && &error($text{'save_eemail'});
$user{'email'} = $in{'email'};
my $raddr = $ENV{'REMOTE_ADDR'};
my @ips;
if ($access{'ips'}) {
	if ($in{'ipmode'}) {
		my @hosts = split(/\s+/, $in{"ips"});
		@hosts || &error($text{'save_enone'});
		foreach my $h (@hosts) {
			my $err = &webmin::valid_allow($h);
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
	$user{'pass'} = &encrypt_password($in{'pass'});
	$user{'sync'} = 0;
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
	foreach my $uu (&useradmin::list_users()) {
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
		my @days = split(/\0/, $in{'days'});
		@days || &error($text{'save_edays'});
		$user{'days'} = join(",", @days);
		}
	if (!$in{'hours_def'}) {
		my %mins;
		foreach my $t ('from', 'to') {
			my $h = $in{'hours_h'.$t};
			my $m = $in{'hours_m'.$t};
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

# Cancel two-factor if requested
if ($in{'cancel'}) {
	$user{'twofactor_provider'} = undef;
	$user{'twofactor_id'} = undef;
	$user{'twofactor_apikey'} = undef;
	}

if ($in{'old'}) {
	# update user and all ACLs
	&modify_user($in{'old'}, \%user);
	if ($in{'old'} ne $user{'name'}) {
		# Change username in other user's ACLs
		foreach my $u (&list_users()) {
			my %uaccess = &get_module_acl($u->{'name'});
			my @au = split(/\s+/, $uaccess{'users'});
			my $idx = &indexof($in{'old'}, @au);
			if ($idx != -1) {
				$au[$idx] = $in{'name'};
				$uaccess{'users'} = join(" ", @au);
				&save_module_acl(\%uaccess, $u->{'name'});
				}
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
	}

my $aclfile = "$config_directory/$in{'name'}.acl";
if ($in{'old'} && $in{'acl_security_form'} && !$newgroup && !$in{'safe'}) {
	# Update user's global ACL
	&foreign_require("", "acl_security.pl");
	my %uaccess;
	&foreign_call("", "acl_security_save", \%uaccess, \%in);
	&lock_file($aclfile);
	&save_module_acl(\%uaccess, $in{'name'}, "", 1);
	&set_ownership_permissions(undef, undef, 0640, $aclfile);
	&unlock_file($aclfile);
	}

# Clear safe setting
if ($in{'unsafe'}) {
	&lock_file($aclfile);
	my %uaccess = &get_module_acl($in{'name'}, "", 1, 1);
	delete($uaccess{'_safe'});
	&save_module_acl(\%uaccess, $in{'name'}, "", 1);
	&unlock_file($aclfile);
	}

# If the user is in safe mode, set ACLs on all new modules
if ($in{'safe'}) {
	foreach my $m ("", @mods) {
		my %macl = &get_module_acl($in{'name'}, $m, 0, 1);
		my $safe = &get_safe_acl($m);
		if (!%macl && $safe) {
			%macl = %$safe;
			$macl{'_safe'} = 1;
			$macl{'noconfig'} = 1;
			&save_module_acl(\%macl, $in{'name'}, $m);
			}
		}
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
&redirect("index.cgi?refresh=1");

