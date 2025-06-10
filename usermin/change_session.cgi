#!/usr/local/bin/perl
# change_session.cgi
# Enable or disable session authentication

require './usermin-lib.pl';
$access{'session'} || &error($text{'acl_ecannot'});
&ReadParse();
&error_setup($text{'session_err'});
$ver = &get_usermin_version();

&lock_file($usermin_miniserv_config);
&get_usermin_miniserv_config(\%miniserv);
$miniserv{'passdelay'} = $in{'passdelay'};

# Save blocked hosts
if ($in{'blockhost_on'}) {
	$in{'blockhost_time'} =~ /^\d+$/ && $in{'blockhost_time'} > 0 ||
		&error($text{'session_eblockhost_time'});
	$in{'blockhost_failures'} =~ /^\d+$/ && $in{'blockhost_failures'} > 0 ||
		&error($text{'session_eblockhost_failures'});
	$miniserv{'blockhost_time'} = $in{'blockhost_time'};
	$miniserv{'blockhost_failures'} = $in{'blockhost_failures'};
	}
else {
	$miniserv{'blockhost_time'} = $miniserv{'blockhost_failures'} = undef;
	}

# Save blocked users
if ($in{'blockuser_on'}) {
	$in{'blockuser_time'} =~ /^\d+$/ && $in{'blockuser_time'} > 0 ||
		&error($text{'session_eblockuser_time'});
	$in{'blockuser_failures'} =~ /^\d+$/ && $in{'blockuser_failures'} > 0 ||
		&error($text{'session_eblockuser_failures'});
	$miniserv{'blockuser_time'} = $in{'blockuser_time'};
	$miniserv{'blockuser_failures'} = $in{'blockuser_failures'};
	}
else {
	$miniserv{'blockuser_time'} = $miniserv{'blockuser_failures'} = undef;
	}

$miniserv{'syslog'} = $in{'syslog'};
if ($in{'session'} && $ENV{'HTTP_COOKIE'} !~ /sessiontest=1/i) {
	&error($text{'session_ecookie'});
	}
$miniserv{'session'} = $in{'session'};
if ($in{'logouttime_on'}) {
	$in{'logouttime'} =~ /^\d+$/ && $in{'logouttime'} > 0 ||
		&error($text{'session_elogouttime'});
	}
$miniserv{'logouttime'} = $in{'logouttime_on'} ? $in{'logouttime'} : undef;
if ($in{'localauth'}) {
	$lsof = &has_command("lsof");
	&error($text{'session_elsof'}) if (!$lsof);
	$miniserv{'localauth'} = $lsof;
	}
else {
	delete($miniserv{'localauth'});
	}
if ($in{'passwd_file'}) {
	$in{'passwd_file'} =~ /\|$/ || -r $in{'passwd_file'} ||
		&error($text{'session_epasswd_file'});
	$in{'passwd_uindex'} =~ /^\d+$/ ||
		&error($text{'session_epasswd_uindex'});
	$in{'passwd_pindex'} =~ /^\d+$/ ||
		&error($text{'session_epasswd_pindex'});
	$miniserv{'passwd_file'} = $in{'passwd_file'};
	$miniserv{'passwd_uindex'} = $in{'passwd_uindex'};
	$miniserv{'passwd_pindex'} = $in{'passwd_pindex'};
	}
else {
	delete($miniserv{'passwd_file'});
	delete($miniserv{'passwd_uindex'});
	delete($miniserv{'passwd_pindex'});
	}
if ($in{'extauth'}) {
	$in{'extauth'} =~ /^(\S+)/ && -x $1 ||
		&error($text{'session_eextauth'});
	$miniserv{'extauth'} = $in{'extauth'};
	}
else {
	delete($miniserv{'extauth'});
	}

if ($ver >= 1.047 && defined($in{'passwd_mode'})) {
	$miniserv{'passwd_mode'} = $in{'passwd_mode'};
	}
if ($ver >= 1.087) {
	$miniserv{'passwd_blank'} = $in{'passwd_blank'};
	}

if ($ver >= 1.003) {
	$miniserv{'domainuser'} = $in{'domainuser'};
	}
if ($ver >= 1.021) {
	$miniserv{'domainstrip'} = $in{'domainstrip'};
	if ($in{'user_mapping_on'}) {
		-r $in{'user_mapping'} || $in{'user_mapping'} =~ /\|$/ ||
			&error($text{'session_eusermap'});
		$miniserv{'user_mapping'} = $in{'user_mapping'};
		}
	else {
		delete($miniserv{'user_mapping'});
		}
	$miniserv{'user_mapping_reverse'} = $in{'user_mapping_reverse'};
	}
&lock_file($miniserv{'userfile'});
@users = &get_usermin_miniserv_users();
if ($in{'authmode'} == 0) {
	delete($miniserv{'no_pam'});
	$users[0]->{'pass'} = 'x';
	}
elsif ($in{'authmode'} == 1) {
	$in{'passwd_file'} || &error($text{'session_eauthmode1'});
	$miniserv{'no_pam'} = 1;
	$users[0]->{'pass'} = 'x';
	}
else {
	$in{'extauth'} || &error($text{'session_eauthmode2'});
	$users[0]->{'pass'} = 'e';
	}
$miniserv{'pam_conv'} = $in{'pam_conv'};
$miniserv{'pam_end'} = $in{'pam_end'};
if ($in{'cmd_def'}) {
	delete($gconfig{'passwd_cmd'});
	}
else {
	$in{'cmd'} =~ /\S/ && &has_command($in{'cmd'}) ||
		&error($text{'session_ecmd'});
	$gconfig{'passwd_cmd'} = $in{'cmd'};
	}
$miniserv{'session_ip'} = $in{'session_ip'};
$miniserv{'utmp'} = $in{'utmp'};
&save_usermin_miniserv_users(@users);
&unlock_file($miniserv{'userfile'});
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);

&lock_file($usermin_config);
&get_usermin_config(\%uconfig);
#$uconfig{'locking'} = $in{'locking'};
$uconfig{'noremember'} = !$in{'remember'};
$uconfig{'realname'} = $in{'realname'};
$uconfig{'forgot_pass'} = $in{'forgot'};
if ($in{'passwd_file'}) {
	$uconfig{'passwd_file'} = $in{'passwd_file'};
	$uconfig{'passwd_uindex'} = $in{'passwd_uindex'};
	$uconfig{'passwd_pindex'} = $in{'passwd_pindex'};
	}
else {
	delete($uconfig{'passwd_file'});
	delete($uconfig{'passwd_uindex'});
	delete($uconfig{'passwd_pindex'});
	}
if ($in{'banner_def'}) {
	delete($uconfig{'loginbanner'});
	}
else {
	-r $in{'banner'} || &error($text{'session_ebanner'});
	$uconfig{'loginbanner'} = $in{'banner'};
	}
$uconfig{'create_homedir'} = $in{'create_homedir'};
if ($in{'create_homedir_perms_def'}) {
	delete($uconfig{'create_homedir_perms'});
	}
else {
	$in{'create_homedir_perms'} =~ /^[0-7]{3,4}$/ ||
		&error($text{'session_ehomedir_perms'});
	$uconfig{'create_homedir_perms'} = $in{'create_homedir_perms'};
	}
&put_usermin_config(\%uconfig);
&unlock_file($usermin_config);

&restart_usermin_miniserv();
&webmin_log("session", undef, undef, \%in);
&redirect("");

