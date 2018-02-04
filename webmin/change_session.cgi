#!/usr/local/bin/perl
# change_session.cgi
# Enable or disable session authentication

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'session_err'});
&foreign_require("acl");

&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
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
$miniserv{'blocklock'} = $in{'blocklock'};

$miniserv{'syslog'} = $in{'syslog'};
if ($in{'session'} && $ENV{'HTTP_COOKIE'} !~ /sessiontest=1/i &&
    !$ENV{'HTTP_WEBMIN_SERVERS'}) {
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
$miniserv{'no_pam'} = $in{'no_pam'};
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
if ($in{'extauth'}) {
	$in{'extauth'} =~ /^(\S+)/ && -x $1 ||
		&error($text{'session_eextauth'});
	$miniserv{'extauth'} = $in{'extauth'};
	}
else {
	delete($miniserv{'extauth'});
	}
if (defined($in{'passwd_mode'})) {
	$miniserv{'passwd_mode'} = $in{'passwd_mode'};
	}
$miniserv{'utmp'} = $in{'utmp'};
$miniserv{'session_ip'} = $in{'session_ip'};
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&lock_file("$config_directory/config");
#$gconfig{'locking'} = $in{'locking'};
$gconfig{'noremember'} = !$in{'remember'};
$gconfig{'realname'} = $in{'realname'};
if ($in{'passwd_file'}) {
	$gconfig{'passwd_file'} = $in{'passwd_file'};
	$gconfig{'passwd_uindex'} = $in{'passwd_uindex'};
	$gconfig{'passwd_pindex'} = $in{'passwd_pindex'};
	}
else {
	delete($gconfig{'passwd_file'});
	delete($gconfig{'passwd_uindex'});
	delete($gconfig{'passwd_pindex'});
	}
if ($in{'banner_def'}) {
	delete($gconfig{'loginbanner'});
	}
else {
	-r $in{'banner'} || &error($text{'session_ebanner'});
	$gconfig{'loginbanner'} = $in{'banner'};
	}
if ($in{'md5pass'} == 1) {
	# MD5 enabled .. but is it supported by this system?
	$need = &acl::check_md5();
	$need && &error(&text('session_emd5mod', "<tt>$need</tt>"));
	}
elsif ($in{'md5pass'} == 2) {
	# SHA512 enabled .. check support
	$need = &acl::check_sha512();
	$need && &error(&text('session_esha512mod', "<tt>$need</tt>"));
	}
$gconfig{'md5pass'} = $in{'md5pass'};
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&show_restart_page();
&webmin_log("session", undef, undef, \%in);

