#!/usr/local/bin/perl
# save_allow.cgi
# Save the cron allow/deny settings

require './cron-lib.pl';
&ReadParse();
$access{'allow'} || &error($text{'allow_ecannot'});

&lock_file($config{cron_allow_file});
&lock_file($config{cron_deny_file});
unlink($config{cron_allow_file});
unlink($config{cron_deny_file});
if ($in{mode} == 1) { &save_allowed(split(/\s+/, $in{'allow'})); }
elsif ($in{mode} == 2) { &save_denied(split(/\s+/, $in{'deny'})); }
&unlock_file($config{cron_allow_file});
&unlock_file($config{cron_deny_file});
&webmin_log("allow");
&redirect("");

