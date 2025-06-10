#!/usr/local/bin/perl
# change_users.cgi
# Update user allow and deny parameters

require './usermin-lib.pl';
$access{'users'} || &error($text{'acl_ecannot'});
use Socket;
&ReadParse();
&error_setup($text{'users_err'});

@users = split(/\s+/, $in{"user"});
if ($in{"access"}) {
	foreach $u (@users) {
		if ($u =~ /^\@(\S+)$/) {
			defined(getgrnam($1)) ||
				&error(&text('users_egroup', "$1"));
			}
		elsif ($u =~ /^(\d*)-(\d*)$/ && ($1 || $2)) {
			# Assume UIDs are ok
			}
		else {
			defined(getpwnam($u)) ||
				&error(&text('users_euser', $u));
			}
		}
	}
if ($in{'shells_deny'}) {
	-r $in{'shells'} || &error($text{'users_eshell'});
	}

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
delete($miniserv{"allowusers"});
delete($miniserv{"denyusers"});
if ($in{"access"} == 1) { $miniserv{"allowusers"} = join(' ', @users); }
elsif ($in{"access"} == 2) { $miniserv{"denyusers"} = join(' ', @users); }
if ($in{'shells_deny'}) {
	$miniserv{'shells_deny'} = $in{'shells'};
	}
else {
	delete($miniserv{'shells_deny'});
	}
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log("users", undef, undef, \%in);
&redirect("");

