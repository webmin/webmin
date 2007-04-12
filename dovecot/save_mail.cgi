#!/usr/local/bin/perl
# Update mail file options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'mail_err'});
&lock_file($config{'dovecot_config'});
$conf = &get_config();

# Mail file location
if ($in{'envmode'} == 4) {
	$in{'other'} =~ /^\S+$/ || &error($text{'mail_eenv'});
	$env = $in{'other'};
	}
else {
	$env = $mail_envs[$in{'envmode'}];
	}
&save_directive($conf, "default_mail_env", $env eq "" ? undef : $env);

# Check and idle intervals
$in{'check'} != 2 || $in{'checki'} =~ /^\d+$/ || &error($text{'mail_echeck'});
&save_directive($conf, "mailbox_check_interval",
	$in{'check'} == 1 ? 0 : $in{'check'} == 2 ? $in{'checki'} : undef);
$in{'idle'} != 2 || $in{'idlei'} =~ /^\d+$/ || &error($text{'mail_eidle'});
&save_directive($conf, "mailbox_idle_check_interval",
	$in{'idle'} == 1 ? 0 : $in{'idle'} == 2 ? $in{'idlei'} : undef);

# Yes/no options
&save_directive($conf, "mail_full_filesystem_access",
		$in{'full'} ? $in{'full'} : undef);
&save_directive($conf, "mail_save_crlf",
		$in{'crlf'} ? $in{'crlf'} : undef);
if (&find("mbox_dirty_syncs", $conf, 2)) {
	&save_directive($conf, "mbox_dirty_syncs",
			$in{'change'} ? $in{'change'} : undef);
	}
else {
	&save_directive($conf, "maildir_check_content_changes",
			$in{'change'} ? $in{'change'} : undef);
	}

# Umask
$in{'umask_def'} || $in{'umask'} =~ /^[0-7]{4}$/ ||&error($text{'mail_eumask'});
&save_directive($conf, "umask",
		$in{'umask_def'} ? undef : $in{'umask'});

# UIDL format
if (&find("pop3_uidl_format", $conf, 2)) {
	$uidl = $in{'pop3_uidl_format'} eq '*' ?
			$in{'pop3_uidl_format_other'} : $in{'pop3_uidl_format'};
	$uidl =~ /^\S+$/ || &error($text{'mail_euid'});
	&save_directive($conf, "pop3_uidl_format", $uidl);
	}

&flush_file_lines();
&unlock_file($config{'dovecot_config'});
&webmin_log("mail");
&redirect("");

