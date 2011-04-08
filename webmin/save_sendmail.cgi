#!/usr/local/bin/perl
# Save mail server settings

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'sendmail_err'});
&foreign_require("mailboxes");
&lock_file($mailboxes::module_config_file);
%mconfig = &foreign_config("mailboxes");

# Save smtp server
if ($in{'mode'} == 0) {
	delete($mconfig{'send_mode'});
	}
elsif ($in{'mode'} == 1) {
	$mconfig{'send_mode'} = '127.0.0.1';
	}
else {
	&to_ipaddress($in{'smtp'}) && &to_ip6address($in{'smtp'}) ||
		&error($text{'sendmail_esmtp'});
	$mconfig{'send_mode'} = $in{'smtp'};
	}

# Save login and password
if ($in{'login_def'}) {
	delete($mconfig{'smtp_user'});
	delete($mconfig{'smtp_pass'});
	}
else {
	$in{'login_user'} =~ /^\S+$/ || &error($text{'sendmail_elogin'});
	$mconfig{'smtp_user'} = $in{'login_user'};
	$mconfig{'smtp_pass'} = $in{'login_pass'};
	}

# Save auth method
$mconfig{'smtp_auth'} = $in{'auth'};

# Save from address
if ($in{'from_def'}) {
	delete($mconfig{'webmin_addr'});
	}
else {
	$in{'from'} =~ /^\S+\@\S+$/ || &error($text{'sendmail_efrom'});
	$mconfig{'webmin_addr'} = $in{'from'};
	}

&save_module_config(\%mconfig, "mailboxes");
&unlock_file($mailboxes::module_config_file);
&webmin_log("sendmail");
&redirect("");

