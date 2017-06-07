#!/usr/local/bin/perl
# save_global.cgi
# Save global majordomo options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
$access{'global'} || &error($text{'global_ecannot'});
&lock_file($config{'majordomo_cf'});
$conf = &get_config();
&error_setup($text{'global_err'});

# Check inputs
$in{'whereami'} =~ /^[A-z0-9\-\.]+$/ ||
	&error($text{'global_ewhereami'});
$in{'whoami'} =~ /^\S+$/ ||
	&error($text{'global_ewhoami'});
$in{'whoami_owner'} =~ /^\S+$/ ||
	&error($text{'global_eowner'});
-x $in{'sendmail_command'} ||
	&error(&text('global_esendmail', "<tt>$in{'sendmail_command'}</tt>"));

# Save inputs
&save_directive($conf, "whereami", $in{'whereami'});
&save_directive($conf, "whoami", $in{'whoami'});
&save_directive($conf, "whoami_owner", $in{'whoami_owner'});
&save_directive($conf, "sendmail_command", $in{'sendmail_command'});
&save_multi_global($conf, "global_taboo_body");
&save_multi_global($conf, "global_taboo_headers");
&flush_file_lines();
&unlock_file($config{'majordomo_cf'});
&webmin_log("global", undef, undef, \%in);
&redirect("edit_global.cgi?saved=true");

