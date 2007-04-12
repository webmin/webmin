#!/usr/local/bin/perl
# save_passwd.cgi
# Create, update or delete a CVS user

require './pserver-lib.pl';
$access{'passwd'} || &error($text{'passwd_ecannot'});
&ReadParse();
@passwd = &list_passwords();
$user = $passwd[$in{'idx'}] if (!$in{'new'});

&lock_file($passwd_file);
if ($in{'delete'}) {
	# Just delete the user
	&delete_password($user);
	}
else {
	# Validate and store inputs
	&error_setup($text{'save_err'});
	$in{'user'} =~ /^[^:\s]+$/ || &error($text{'save_euser'});
	$user->{'user'} = $in{'user'};
	if ($in{'pass_def'} == 2) {
		$user->{'pass'} = undef;
		}
	elsif ($in{'pass_def'} == 0) {
		local $salt = chr(int(rand(26))+65) . chr(int(rand(26))+65);
		$user->{'pass'} = &unix_crypt($in{'pass'}, $salt);
		}
	elsif ($in{'pass_def'} == 3) {
		&foreign_require("useradmin", "user-lib.pl");
		@users = &useradmin::list_users();
		($copy) = grep { $_->{'user'} eq $in{'user'} } @users;
		$copy || &error($text{'save_ecopy'});
		$copy->{'pass'} =~ /^\$1\$/ &&  &error($text{'save_emd5'});
		$user->{'pass'} = $copy->{'pass'};
		}
	if ($in{'unix_def'}) {
		$user->{'unix'} = undef;
		}
	else {
		defined(getpwnam($in{'unix'})) || &error($text{'save_eunix'});
		$user->{'unix'} = $in{'unix'};
		}

	# Save or create the user
	if ($in{'new'}) {
		&create_password($user);
		}
	else {
		&modify_password($user);
		}
	}
&unlock_file($passwd_file);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "user", $user->{'user'}, $user);
&redirect("list_passwd.cgi");

