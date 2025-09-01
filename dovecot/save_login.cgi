#!/usr/local/bin/perl
# Update login options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'login_err'});
$conf = &get_config();
&lock_dovecot_files($conf);

# Allowed and default realm
&save_directive($conf, "auth_realms",
		$in{'realms_def'} ? undef : $in{'realms'});
&save_directive($conf,
		&version_atleast("2.4")
			? "auth_default_domain"
			: "auth_default_realm",
		$in{'realm_def'} ? undef : $in{'realm'});

# Authentication mechanisms
if (&find("auth_mechanisms", $conf, 2)) {
	&save_directive($conf, "auth_mechanisms",
			$in{'mechs'}
				? join(" ", split(/\0/, $in{'mechs'}))
				: undef);
	}
else {
	&save_directive($conf, "mechanisms",
			join(" ", split(/\0/, $in{'mechs'})), "auth","default");
	}

if (&version_below("2.4")) {
	# User database
	$userdb = $in{'usermode'};
	if ($in{'usermode'} eq 'passwd-file') {
		-r $in{'passwdfile'} || &error($text{'login_epasswdfile'});
		$userdb .= " ".$in{'passwdfile'};
		}
	elsif ($in{'usermode'} eq 'static') {
		$in{'uid'} =~ /^\d+$/ || &error($text{'login_euid'});
		$in{'gid'} =~ /^\d+$/ || &error($text{'login_egid'});
		$in{'home'} || &error($text{'login_ehome'});
		$userdb .= " uid=".$in{'uid'}." gid=".$in{'gid'}.
			" home=".$in{'home'};
		}
	elsif ($in{'usermode'} eq 'ldap') {
		-r $in{'ldap'} || &error($text{'login_eldap'});
		$userdb .= " ".$in{'ldap'};
		}
	elsif ($in{'usermode'} eq 'pgsql') {
		-r $in{'pgsql'} || &error($text{'login_epgsql'});
		$userdb .= " ".$in{'pgsql'};
		}
	elsif ($in{'usermode'} eq 'sql') {
		-r $in{'sql'} || &error($text{'login_esql'});
		$userdb .= " ".$in{'sql'};
		}
	elsif ($in{'usermode'} eq '') {
		$userdb = $in{'other'};
		}
	if ($usec = &find_section("userdb", $conf, undef, "auth", "default")) {
		# Version 1.0.alpha format, which has a userdb *section*
		($svalue, $args) = split(/\s+/, $userdb, 2);
		$usec->{'value'} = $svalue;
		$usec->{'members'} = [ grep { $_->{'name'} ne 'args' }
					@{$usec->{'members'}} ];
		if ($args) {
			$usec->{'members'} = [ { 'name' => 'args',
						'value' => $args } ];
			}
		&save_section($conf, $usec);
		}
	elsif (&find("auth_userdb", $conf, 2)) {
		# Version 0.99 format
		&save_directive($conf, "auth_userdb", $userdb);
		}
	elsif (&find_value("driver", $conf, 2, "userdb")) {
		# Version 2.0 format
		$args = $userdb =~ s/\s+(\S.*)$// ? $1 : undef;
		&save_directive($conf, "driver", $userdb, "userdb");
		&save_directive($conf, "args", $args, "userdb");
		}
	else {
		# Version 1.0 format
		&save_directive($conf, "userdb", $userdb, "auth", "default");
		}

	# Password mode
	$passdb = $in{'passmode'};
	if ($in{'passmode'} eq 'dpam') {
		$passdb = "pam";
		}
	elsif ($in{'passmode'} eq 'pam') {
		$in{'ppam'} =~ /^\S+$/ || &error($text{'login_edpam'});
		if (defined($in{'ppam_ckey'}) && !$in{'ppam_ckey_def'}) {
			$ckey = $in{'ppam_ckey'};
			$ckey =~ /^\S+$/ || &error($text{'login_eckey'});
			}
		$passdb .= ($in{'ppam_session'} ? " -session" : "").
			($ckey ? " cache_key=$ckey" : "").
			" ".$in{'ppam'};
		}
	elsif ($in{'passmode'} eq 'passwd-file') {
		-r $in{'ppasswdfile'} || &error($text{'login_epasswdfile'});
		$passdb .= " ".$in{'ppasswdfile'};
		}
	elsif ($in{'passmode'} eq 'ldap') {
		-r $in{'pldap'} || &error($text{'login_eldap'});
		$passdb .= " ".$in{'pldap'};
		}
	elsif ($in{'passmode'} eq 'pgsql') {
		-r $in{'ppgsql'} || &error($text{'login_epgsql'});
		$passdb .= " ".$in{'ppgsql'};
		}
	elsif ($in{'passmode'} eq 'sql') {
		-r $in{'psql'} || &error($text{'login_esql'});
		$passdb .= " ".$in{'psql'};
		}
	elsif ($in{'passmode'} eq 'bsdauth') {
		$in{'bsdauth_ckey_def'} || $in{'bsdauth_ckey'} =~ /^\S+$/ ||
			&error($text{'login_eckey'});
		$passdb .= " cache_key=$in{'bsdauth_ckey'}"
			if (!$in{'bsdauth_ckey_def'});
		}
	elsif ($in{'passmode'} eq 'checkpassword') {
		-x $in{'checkpassword'} || &error($text{'login_echeckpassword'});
		$passdb .= " ".$in{'checkpassword'};
		}
	elsif ($in{'passmode'} eq '') {
		$passdb = $in{'other'};
		}
	# XXX other modes
	if ($psec = &find_section("passdb", $conf, undef, "auth", "default")) {
		# Version 1.0.alpha format
		($svalue, $args) = split(/\s+/, $passdb, 2);
		$psec->{'value'} = $svalue;
		$psec->{'members'} = [ grep { $_->{'name'} ne 'args' }
					@{$psec->{'members'}} ];
		if ($args) {
			$psec->{'members'} = [ { 'name' => 'args',
						'value' => $args } ];
			}
		&save_section($conf, $psec);
		}
	elsif (&find("auth_passdb", $conf, 2)) {
		# Version 0.99 format
		&save_directive($conf, "auth_passdb", $passdb);
		}
	elsif (&find_value("driver", $conf, 2, "passdb")) {
		# Version 2.0 format
		$args = $passdb =~ s/\s+(\S.*)$// ? $1 : undef;
		&save_directive($conf, "driver", $passdb, "passdb");
		&save_directive($conf, "args", $args, "passdb");
		}
	else {
		# Version 1.0 format
		&save_directive($conf, "passdb", $passdb, "auth", "default");
		}
	}

# Allowed UIDs and GIDs
$in{'fuid_def'} || $in{'fuid'} =~ /^\d+$/ || &error($text{'login_efuid'});
&save_directive($conf, "first_valid_uid",
		$in{'fuid_def'} ? undef : $in{'fuid'});

$in{'luid_def'} || $in{'luid'} =~ /^\d+$/ || &error($text{'login_eluid'});
&save_directive($conf, "last_valid_uid",
		$in{'luid_def'} ? undef : $in{'luid'});

$in{'fgid_def'} || $in{'fgid'} =~ /^\d+$/ || &error($text{'login_efgid'});
&save_directive($conf, "first_valid_gid",
		$in{'fgid_def'} ? undef : $in{'fgid'});

$in{'lgid_def'} || $in{'lgid'} =~ /^\d+$/ || &error($text{'login_elgid'});
&save_directive($conf, "last_valid_gid",
		$in{'lgid_def'} ? undef : $in{'lgid'});

&save_directive($conf,
		&version_atleast("2")
			? "mail_access_groups"
			: "mail_extra_groups",
		$in{'extra_def'} ? undef : $in{'extra'});

$in{'chroot_def'} || -d $in{'chroot'} || &error($text{'login_echroot'});
&save_directive($conf, "mail_chroot",
		$in{'chroot_def'} ? undef : $in{'chroot'});

if (&find("login_max_processes_count", $conf, 2)) {
	$in{'procs_def'} || $in{'procs'} =~ /^\d+$/ ||
		&error($text{'login_eprocs'});
	&save_directive($conf, "login_max_processes_count",
			$in{'procs_def'} ? undef : $in{'procs'});
	}

if (&find("login_processes_count", $conf, 2)) {
	$in{'count_def'} || $in{'count'} =~ /^\d+$/ ||
		&error($text{'login_ecount'});
	&save_directive($conf, "login_processes_count",
			$in{'count_def'} ? undef : $in{'count'});
	}

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("login");
&redirect("");

