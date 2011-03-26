#!/usr/local/bin/perl
# Update mail file options

require './dovecot-lib.pl';
&ReadParse();
&error_setup($text{'mail_err'});
$conf = &get_config();
&lock_dovecot_files($conf);

# Mail file location
if ($in{'envmode'} == 4) {
	$in{'other'} =~ /^\S+$/ || &error($text{'mail_eenv'});
	$env = $in{'other'};
	}
else {
	$env = $mail_envs[$in{'envmode'}];
	}

# Add index file location
$env || !$in{'indexmode'} || &error($text{'mail_eindexmode'});
$env || !$in{'controlmode'} || &error($text{'mail_econtrolmode'});
if ($in{'indexmode'} == 1) {
	$env .= ":INDEX=MEMORY";
	}
elsif ($in{'indexmode'} == 2) {
	$in{'index'} =~ /^\/\S+$/ || &error($text{'mail_eindex'});
	$env .= ":INDEX=".$in{'index'};
	}
if ($in{'controlmode'}) {
	$in{'control'} =~ /^\/\S+$/ || &error($text{'mail_econtrol'});
	$env .= ":CONTROL=".$in{'control'};
	}

if (&find("mail_location", $conf, 2)) {
	&save_directive($conf, "mail_location", $env eq "" ? undef : $env);
	}
else {
	&save_directive($conf, "default_mail_env", $env eq "" ? undef : $env);
	}

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
	$uidl =~ /^\S+$/ || &error($text{'mail_euidl'});
	&save_directive($conf, "pop3_uidl_format", $uidl);
	}

# LAST command
&save_directive($conf, "pop3_enable_last",
		$in{'last'} ? $in{'last'} : undef);

# Index lock method
if (&find("lock_method", $conf, 2)) {
	&save_directive($conf, "lock_method",
			$in{'lock_method'} ? $in{'lock_method'} : undef);
	}

# Mailbox lock method
foreach $l ("mbox_read_locks", "mbox_write_locks") {
	next if (!&find($l, $conf, 2));
	if ($in{$l."_def"}) {
		&save_directive($conf, $l, undef);
		}
	else {
		@methods = ( );
		for(my $i=0; defined($m = $in{$l."_".$i}); $i++) {
			push(@methods, $m) if ($m);
			}
		@methods || &error($text{'mail_e'.$l});
		&save_directive($conf, $l, join(" ", @methods));
		}
	}

&flush_file_lines();
&unlock_dovecot_files($conf);
&webmin_log("mail");
&redirect("");

