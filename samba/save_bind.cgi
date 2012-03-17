#!/usr/local/bin/perl
# save_bind.cgi
# Save inputs from conf_bind.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_bind'};
 
&error_setup($text{'bind_err'});
&setval("winbind enable local accounts", $in{'local'} ? "yes" : "no");

&setval("winbind trusted domains only", $in{'trust'} ? "yes" : "no");

&setval("winbind enum users", $in{'users'} ? "yes" : "no");

&setval("winbind enum groups", $in{'groups'} ? "yes" : "no");

&setval("winbind use default domain", $in{'defaultdomain'} ? "yes" : "no");

$in{'realm'} eq "" || $in{'realm'} =~ /^\S+$/ || &error($text{'bind_erealm'});
&setval("realm", $in{'realm'});

$in{'cache'} =~ /^\d+$/ || &error($text{'bind_ecache'});
&setval("winbind cache time", $in{'cache'});

$in{'uid'} eq "" || $in{'uid'} =~ /^\d+\-\d+$/ || &error($text{'bind_euid'});
&setval("idmap uid", $in{'uid'});

$in{'gid'} eq "" || $in{'gid'} =~ /^\d+\-\d+$/ || &error($text{'bind_egid'});
&setval("idmap gid", $in{'gid'});

&setval("idmap backend", $in{'backend_def'} ? "" : $in{'backend'});

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("bind", undef, undef, \%in);
&redirect("");

