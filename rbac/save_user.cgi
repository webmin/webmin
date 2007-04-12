#!/usr/local/bin/perl
# Create, update or delete one RBAC user

require './rbac-lib.pl';
&ReadParse();
&error_setup($text{'user_err'});

&lock_rbac_files();
$users = &list_user_attrs();
if (!$in{'new'}) {
	$user = $users->[$in{'idx'}];
	&can_edit_user($user) || &error($text{'user_ecannot'});
	$loguser = $user->{'user'};
	@oldroles = split(/,/, $user->{'attr'}->{'roles'});
	@oldprofs = split(/,/, $user->{'attr'}->{'profiles'});
	}
else {
	$access{'users'} || $access{'roles'} || &error($text{'user_ecannot'});
	$user = { 'attr' => { } };
	$loguser = $in{'user'};
	}

if (!$in{'new'}) {
	# Find users of this role
	foreach $u (@$users) {
		local @roles =
		    split(/,/, $u->{'attr'}->{'roles'});
		$idx = &indexof($loguser, @roles);
		if ($idx >= 0) {
			push(@roleusers, [ $u, $idx, \@roles ]);
			}
		}
	}

if ($in{'delete'}) {
	# Just delete this user
	@roleusers && &error(&text('user_einuse',
				   $roleusers[0]->[0]->{'user'}));
	&delete_user_attr($user);
	}
else {
	# Check for clash
	if ($in{'new'} || $loguser ne $in{'user'}) {
		($clash) = grep { $_->{'user'} eq $in{'user'} } @$users;
		$clash && &error($text{'user_eclash'});
		}

	# Validate and store inputs
	$in{'user'} =~ /^[^ :]+$/ || &error($text{'user_euser'});
	$user->{'user'} = $in{'user'};
	if (!$access{'users'}) {
		# Type must be role
		$user->{'attr'}->{'type'} = 'role';
		}
	elsif (!$access{'roles'}) {
		# Type must be user
		$user->{'attr'}->{'type'} = 'normal';
		}
	elsif ($in{'type'}) {
		# A type was selected
		$user->{'attr'}->{'type'} = $in{'type'};
		}
	else {
		# Default type chosen
		delete($user->{'attr'}->{'type'});
		}
	$profiles = &profiles_parse("profiles");
	if ($profiles) {
		@profiles = split(/,/, $profiles);
		foreach $p (@profiles) {
			if (!&can_assign_profile($p) &&
			    &indexof($p, @oldprofs) == -1) {
				&error(&text('user_eprof', $p));
				}
			}
		$user->{'attr'}->{'profiles'} = $profiles;
		}
	else {
		delete($user->{'attr'}->{'profiles'});
		}
	if ($access{'authassign'}) {
		$auths = &auths_parse("auths");
		if ($auths) {
			$user->{'attr'}->{'auths'} = $auths;
			}
		else {
			delete($user->{'attr'}->{'auths'});
			}
		}
	$roles = &attr_parse("roles");
	if ($roles) {
		@roles = split(/,/, $roles);
		&indexof($in{'user'}, @roles) < 0 ||
			&error($text{'user_esub'});
		foreach $r (@roles) {
			if (!&can_assign_role($r) &&
			    &indexof($r, @oldroles) == -1) {
				&error(&text('user_erole', $r));
				}
			}
		$user->{'attr'}->{'roles'} = $roles;
		}
	else {
		delete($user->{'attr'}->{'roles'});
		}
	if ($in{'project_def'}) {
		delete($user->{'attr'}->{'project'});
		}
	else {
		$user->{'attr'}->{'project'} = $in{'project'};
		}
	if ($in{'lock'}) {
		$user->{'attr'}->{'lock_after_retries'} = $in{'lock'};
		}
	else {
		delete($user->{'attr'}->{'lock_after_retries'});
		}

	# Save or update user
	if ($in{'new'}) {
		&create_user_attr($user);
		}
	else {
		&modify_user_attr($user);

		# Update other users of this role, if renamed
		if ($loguser ne $in{'user'}) {
			foreach $ru (@roleusers) {
				$ru->[2]->[$ru->[1]] = $in{'user'};
				$ru->[0]->{'attr'}->{'roles'} =
					join(",", @{$ru->[2]});
				&modify_user_attr($ru->[0]);
				}
			}
		}
	}

&unlock_rbac_files();
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "user", $loguser, $user);
&redirect("list_users.cgi");

