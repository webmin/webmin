#!/usr/local/bin/perl
# save_user.cgi
# Create, update or delete a password file user

require './htaccess-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
@dirs = &list_directories();
($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
&lock_file($dir->[1]);

&switch_user();
$users = $dir->[2] == 3 ? &list_digest_users($dir->[1])
			: &list_users($dir->[1]);
if (!$in{'new'}) {
	$user = $users->[$in{'idx'}];
	$loguser = $user->{'user'};
	}
else {
	$loguser = $in{'htuser'};
	}

if ($in{'delete'}) {
	# Just delete this user
	&delete_user($user);
	}
else {
	# Validate inputs
	$in{'htuser'} || &error($text{'save_euser1'});
	$in{'htuser'} =~ /:/ && &error($text{'save_euser2'});
	if ($in{'new'} || $user->{'user'} ne $in{'htuser'}) {
		($clash) = grep { $_->{'user'} eq $in{'htuser'} } @$users;
		$clash && &error($text{'save_eclash'});
		}
	!$in{'htpass_def'} && $in{'htpass'} =~ /:/ &&
		&error($text{'save_epass'});

	# Actually save
	$user->{'user'} = $in{'htuser'};
	if (!$in{'htpass_def'}) {
		if ($dir->[2] == 3) {
			$user->{'pass'} = &digest_password($in{'htuser'},
					$in{'dom'}, $in{'htpass'});
			}
		else {
			$user->{'pass'} = &encrypt_password(
					$in{'htpass'}, undef, $dir->[2]);
			}
		}
	$user->{'enabled'} = $in{'enabled'};
	if ($dir->[2] == 3) {
		$in{'dom'} =~ /^\S+$/ && $in{'dom'} !~ /:/ ||
			&error($text{'save_edom'});
		$user->{'dom'} = $in{'dom'};
		$user->{'digest'} = 1;
		}
	if ($in{'new'}) {
		&create_user($user, $dir->[1]);
		}
	else {
		&modify_user($user);
		}
	}
&switch_back();

&unlock_file($dir->[1]);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "user", $loguser, $user);
&redirect("");

