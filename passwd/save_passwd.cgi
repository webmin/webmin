#!/usr/local/bin/perl
# save_passwd.cgi
# Change a user's password

require './passwd-lib.pl';
&error_setup($text{'passwd_err'});
&ReadParse();

if ($config{'passwd_cmd'}) {
	# Call the passwd program to do the change
	@user = getpwnam($in{'user'});
	@user || &error($text{'passwd_euser'});
	&can_edit_passwd(\@user) || &error($text{'passwd_ecannot'});
	if ($access{'repeat'}) {
		$in{'new'} eq $in{'repeat'} || &error($text{'passwd_erepeat'});
		}
	&foreign_require("proc", "proc-lib.pl");
	if ($access{'old'} == 1 ||
	    $access{'old'} == 2 && $in{'user'} ne $remote_user) {
		@cmd = ( $config{'passwd_cmd'}, $user[2], $user[3] );
		}
	else {
		@cmd = ( "$config{'passwd_cmd'} '$in{'user'}'" );
		}
	&additional_log('exec', undef, $cmd[0]);
	local ($fh, $fpid) = &foreign_call("proc", "pty_process_exec", @cmd);
	while(1) {
		local $rv = &wait_for($fh, '(new|re-enter).*:',
					   '(old|current|login).*:',
					   'pick a password');
		$out .= $wait_for_input;
		sleep(1);
		if ($rv == 0) {
			syswrite($fh, $in{'new'}."\n", length($in{'new'})+1);
			}
		elsif ($rv == 1) {
			syswrite($fh, $in{'old'}."\n", length($in{'old'})+1);
			}
		elsif ($rv == 2) {
			syswrite($fh, "1\n", 2);
			}
		else {
			last;
			}
		last if (++$count > 10);
		}
	close($fh);
	waitpid($fpid, 0);
	&error(&text('passwd_ecmd', "<tt>$config{'passwd_cmd'}</tt>", "<pre>$out</pre>")) if ($? || $count > 10);
	&webmin_log("passwd", undef, $in{'user'});
	}
else {
	# Update the config files directly via the useradmin module
	&foreign_require("useradmin", "user-lib.pl");

	# Find the user, either in local password file or LDAP
	$user = &find_user($in{'user'});

	if ($user) {
		# Validate inputs
		if ($access{'old'} == 1 ||
		    $access{'old'} == 2 && $user->{'user'} ne $remote_user) {
			&useradmin::validate_password(
			    $in{'old'}, $user->{'pass'}) ||
				&error($text{'passwd_eold'});
			}
		if ($access{'repeat'}) {
			$in{'new'} eq $in{'repeat'} || &error($text{'passwd_erepeat'});
			}
		$err = &useradmin::check_password_restrictions(
			$in{'new'}, $in{'user'}, $user);
		&error($err) if ($err);

		&can_edit_passwd([ $user->{'user'}, $user->{'pass'},
				   $user->{'uid'}, $user->{'gid'} ]) ||
			&error($text{'passwd_ecannot'});

		# Actually do the change
		&change_password($user, $in{'new'}, 
			$access{'others'} == 1 ||
			$access{'others'} == 2 && $in{'others'});
		}
	else {
		&error($text{'passwd_euser'});
		}
	delete($user->{'plainpass'});
	delete($user->{'pass'});
	&webmin_log("passwd", undef, $user->{'user'}, $user);
	}

# Show a confirmation message
&ui_print_header(undef, $text{'passwd_title'}, "");
if (($user->{'user'} eq $remote_user || $user->{'user'} eq $base_remote_user) &&
    !$main::session_id) {
	print &text('passwd_ok', "<tt>$user->{'user'}</tt>"),"\n";
	}
else {
	print &text('passwd_ok2', "<tt>$user->{'user'}</tt>"),"\n";
	}
&ui_print_footer($in{'one'} ? ( "/", $text{'index'} )
			    : ( "", $text{'index_return'} ));

