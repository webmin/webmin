#!/usr/local/bin/perl
# save_user.cgi
# Create, update or delete a password file user

require './htpasswd-file-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});
$users = &list_users();
if (!$in{'new'}) {
	if (!$access{'single'}) {
		$user = $users->[$in{'idx'}];
		}
	else {
		($user) = grep { $_->{'user'} eq $in{'user'} } @$users;
		$user || &error($text{'save_euser'});
		}
	$loguser = $user->{'user'};
	}
else {
	$loguser = $in{'user'};
	}

&lock_file($config{'file'});
if ($in{'delete'}) {
	# Just delete this user
	$access{'delete'} || &error($text{'save_edelete'});
	&delete_user($user);
	}
else {
	# Validate inputs
	if (!$access{'single'} && $access{'rename'} || $in{'new'}) {
		$in{'user'} || &error($text{'save_euser1'});
		$in{'user'} =~ /:/ && &error($text{'save_euser2'});
		if ($in{'new'} || $user->{'user'} ne $in{'user'}) {
			($clash) = grep { $_->{'user'} eq $in{'user'} } @$users;
			$clash && &error($text{'save_eclash'});
			}
		}
	!$in{'pass_def'} && $in{'pass'} =~ /:/ && &error($text{'save_epass'});
	if ($access{'repeat'} && !$in{'new'}) {
		$user->{'pass'} eq &encrypt_password($in{'oldpass'}, $user->{'pass'}, $config{'md5'}) || &error($text{'save_eoldpass'});
		}

	# Actually save
	$user->{'user'} = $in{'user'}
		if ($in{'new'} || !$access{'single'} && $access{'rename'});
	if (!$in{'pass_def'}) {
		$user->{'pass'} = &encrypt_password($in{'pass'}, undef, $config{'md5'});
		}
	if ($access{'enable'}) {
		$user->{'enabled'} = $in{'enabled'};
		}
	elsif ($in{'new'}) {
		$user->{'enabled'} = 1;
		}
	if ($in{'new'}) {
		&create_user($user);
		}
	else {
		&modify_user($user);
		}
	}
&unlock_file($config{'file'});
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "user", $loguser, $user);
if ($access{'single'}) {
	&ui_print_header(undef, $text{'save_title'}, "");
	print &text('save_done', "<tt>$loguser</tt>"),"<p>\n";
	&ui_print_footer("edit.cgi", $text{'edit_return'});
	}
else {
	&redirect("");
	}


