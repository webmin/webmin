#!/usr/local/bin/perl
# save_user.cgi
# Save, create or delete a MON user

require './mon-lib.pl';
&ReadParse();
&error_setup($text{'user_err'});
@users = &list_users();
$user = $users[$in{'index'}] if ($in{'index'} ne '');

if ($in{'delete'}) {
	# Just delete the user
	&delete_user($user);
	}
else {
	# Validate inputs
	$in{'user'} =~ /^[^:\s]+$/ || &error($text{'user_euser'});
	if ($in{'new'} || $in{'user'} ne $user->{'user'}) {
		local ($same) = grep { $_->{'user'} eq $in{'user'} } @users;
		$same && &error($text{'user_esame'});
		}

	# Create or update the user
	$salt = substr(time(), -2);
	$user->{'user'} = $in{'user'};
	if (!$in{'pass_def'}) {
		$user->{'pass'} = &unix_crypt($in{'pass'}, $salt);
		}
	if ($in{'new'}) {
		&create_user($user);
		}
	else {
		&modify_user($user);
		}
	}

&redirect("list_users.cgi");

