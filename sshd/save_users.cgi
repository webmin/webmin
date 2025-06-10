#!/usr/local/bin/perl
# save_users.cgi
# save user and group related sshd options

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'users_err'});
&lock_file($config{'sshd_config'});
$conf = &get_sshd_config();

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	if ($in{'expire_def'}) {
		&save_directive("AccountExpireWarningDays", $conf);
		}
	else {
		$in{'expire'} =~ /^\d+$/ || &error($text{'users_eexpire'});
		&save_directive("AccountExpireWarningDays", $conf,
				$in{'expire'});
		}
	}

if ($version{'type'} eq 'ssh' || $version{'number'} < 3.1) {
	&save_directive("CheckMail", $conf, $in{'mail'} ? 'yes' : 'no');
	}

#&save_directive("ForcedEmptyPasswdChange", $conf, $in{'empty'} ? 'yes' : 'no');
#
#&save_directive("ForcedPasswdChange", $conf, $in{'passwd'} ? 'yes' : 'no');

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	if ($in{'pexpire_def'}) {
		&save_directive("PasswdExpireWarningDays", $conf);
		}
	else {
		$in{'pexpire'} =~ /^\d+$/ || &error($text{'users_eexpire'});
		&save_directive("PasswdExpireWarningDays", $conf,
				$in{'pexpire'});
		}
	}

if ($version{'type'} ne 'ssh' || $version{'number'} < 3) {
	&save_directive("PasswordAuthentication", $conf,
			$in{'auth'} ? 'yes' : 'no');
	}

&save_directive("PermitEmptyPasswords", $conf, $in{'pempty'} ? 'yes' : 'no');

&save_directive("PermitRootLogin", $conf, $in{'root'} || undef);

if (($version{'type'} eq 'ssh' && $version{'number'} < 3) ||
    ($version{'type'} eq 'openssh' && $version{'number'} < 7.3)) {
	&save_directive("RSAAuthentication", $conf, $in{'rsa'} ? 'yes' : 'no');
	}
if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	&save_directive("PubkeyAuthentication", $conf,
			$in{'dsa'} ? 'yes' : 'no');
	}

&save_directive("StrictModes", $conf, $in{'strict'} ? 'yes' : 'no');

&save_directive("PrintMotd", $conf, $in{'motd'} ? 'yes' : 'no');

if ($version{'type'} eq 'openssh') {
	&save_directive("IgnoreUserKnownHosts", $conf,
			$in{'known'} ? 'yes' : 'no');

	if ($version{'number'} > 2.3) {
		if ($in{'banner_def'}) {
			&save_directive("Banner", $conf);
			}
		else {
			-r $in{'banner'} || &error($text{'users_ebanner'});
			&save_directive("Banner", $conf, $in{'banner'});
			}
		}
	}
elsif ($version{'type'} eq 'ssh' && $version{'number'} >= 2) {
	if ($in{'banner_def'}) {
		&save_directive("BannerMessageFile", $conf);
		}
	else {
		-r $in{'banner'} || &error($text{'users_ebanner'});
		&save_directive("BannerMessageFile", $conf, $in{'banner'});
		}
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 3) {
	if ($in{'authkeys_def'}) {
		&save_directive("AuthorizedKeysFile", $conf);
		}
	else {
		$in{'authkeys'} =~ /^\S+$/ || &error($text{'users_eauthkeys'});
		&save_directive("AuthorizedKeysFile", $conf, $in{'authkeys'});
		}
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 5) {
	if ($in{'maxauthtries_def'}) {
		&save_directive("MaxAuthTries", $conf);
		}
	else {
		$in{'maxauthtries'} =~ /^\d+$/ && $in{'maxauthtries'} > 0 ||
			&error($text{'users_emaxauthtries'});
		&save_directive("MaxAuthTries", $conf, $in{'maxauthtries'});
		}
	}

if ($version{'type'} eq 'openssh' && $version{'number'} < 3.7 ||
    $version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&save_directive("RhostsAuthentication", $conf,
			$in{'rhostsauth'} ? 'yes' : 'no');

	&save_directive("RhostsRSAAuthentication", $conf,
			$in{'rhostsrsa'} ? 'yes' : 'no');
	}

if ($version{'type'} eq 'openssh' && $version{'number'} >= 5) {
	my $chall_name = $version{'number'} >= 6.2 ?
		"KbdInteractiveAuthentication" : "ChallengeResponseAuthentication";
	&save_directive($chall_name, $conf, $in{'chal'} ? 'yes' : 'no');
	}

&save_directive("IgnoreRhosts", $conf, $in{'rhosts'} ? 'yes' : 'no');

if ($version{'type'} eq 'ssh') {
	if ($in{'rrhosts'} == -1) {
		&save_directive("IgnoreRootRhosts", $conf);
		}
	else {
		&save_directive("IgnoreRootRhosts", $conf,
				$in{'rrhosts'} ? 'yes' : 'no');
		}
	}

&flush_file_lines();
&unlock_file($config{'sshd_config'});
&webmin_log("users");
&redirect("");

