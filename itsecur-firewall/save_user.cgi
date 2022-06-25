#!/usr/bin/perl
# save_user.cgi
# Create, update or delete a Webmin user

require './itsecur-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&can_edit_error("users");
&ReadParse();
&lock_itsecur_files();
@users = &acl::list_users();
if (!$in{'new'}) {
	($user) = grep { $_->{'name'} eq $in{'old'} } @users;
	}

if ($in{'delete'}) {
	# Delete him
	&automatic_backup();
	&acl::delete_user($user->{'name'});
	}
else {
	# Validate and store inputs
	&error_setup($text{'user_err'});
	$in{'name'} || &error($text{'user_ename'});
	$in{'name'} =~ /^[A-z0-9\-\_\.]+$/ ||
		&error(&acl::text('save_ename', $in{'name'}));
	$in{'name'} eq 'webmin' && &error($acl::text{'save_enamewebmin'});
	if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
		foreach $u (@users, &acl::list_groups()) {
			if ($u->{'name'} eq $in{'name'}) {
				&error(&acl::text('save_edup', $in{'name'}));
				}
			}
		}
	$user->{'name'} = $in{'name'};
	if (!$in{'same'}) {
		if (defined(&acl::encrypt_password)) {
			$user->{'pass'} = &acl::encrypt_password($in{'pass'});
			}
		else {
			$salt = substr(time(), -8);
			$user->{'pass'} = crypt($in{'pass'}, $salt);
			}
		}
	$locked = ($user->{'pass'} =~ /^\*LK\*/);
	if ($in{'enabled'} && $locked) {
		$user->{'pass'} = substr($user->{'pass'}, 4);
		}
	elsif (!$in{'enabled'} && !$locked) {
		$user->{'pass'} = "*LK*".$user->{'pass'};
		}

	# Validate and save IPs
	if ($in{'ipmode'}) {
		@hosts = split(/\s+/, $in{"ips"});
		if (!@hosts) { &error($acl::text{'save_enone'}); }
		foreach $h (@hosts) {
			if ($h =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
				&check_ipaddress($1) ||
					&error(&acl::text('save_enet', $1));
				&check_ipaddress($2) ||
					&error(&acl::text('save_emask', $2));
				$i = $h;
				}
			elsif ($h =~ /^[0-9\.]+$/) {
				&check_ipaddress($h) ||
					&error(&acl::text('save_eip', $h));
				$i = $h;
				}
			elsif ($h =~ /^\*\.(\S+)$/) {
				$i = $h;
				}
			elsif ($h eq 'LOCAL') {
				$i = 'LOCAL';
				}
			elsif (!($i = join('.',unpack("CCCC",inet_aton($h))))) {
				&error(&acl::text('save_ehost', $h));
				}
			push(@ips, $i);
			}
		}
	delete($user->{'allow'});
	delete($user->{'deny'});
	if ($in{'ipmode'} == 1) {
		$user->{'allow'} = join(" ", @ips);
		}
	elsif ($in{'ipmode'} == 2) {
		$user->{'deny'} = join(" ", @ips);
		}

	&automatic_backup();

	$user->{'modules'} = [ split(/\0/, $in{'mods'}) ];
	if ($in{'new'}) {
		# Create the user
		&acl::create_user($user);
		}
	else {
		# Modify the user
		&acl::modify_user($in{'old'}, $user);
		}

	# Update his ACL
	require "./acl_security.pl";
	%uaccess = &get_module_acl($in{'name'});
	&acl_security_save(\%uaccess);
	if ($in{'new'}) {
		$uaccess{'noconfig'} = 1;
		}
	&save_module_acl(\%uaccess, $in{'name'});
	}
&acl::restart_miniserv();
&unlock_itsecur_files();
&remote_webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "update",
	    "user", $user->{'name'}, $user);
&redirect("list_users.cgi");

