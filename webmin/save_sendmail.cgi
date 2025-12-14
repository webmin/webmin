#!/usr/local/bin/perl
# Save mail server settings

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'sendmail_err'});
&foreign_require("mailboxes");
&lock_file($mailboxes::module_config_file);
&lock_file("$config_directory/config");
%mconfig = &foreign_config("mailboxes");

# Save smtp server
if ($in{'mode'} == 0) {
	delete($mconfig{'send_mode'});
	}
elsif ($in{'mode'} == 1) {
	$mconfig{'send_mode'} = '127.0.0.1';
	delete($mconfig{'smtp_port'});
	$mconfig{'smtp_ssl'} = $in{'ssl'};
	}
else {
	&to_ipaddress($in{'smtp'}) || &to_ip6address($in{'smtp'}) ||
		&error($text{'sendmail_esmtp'});
	$mconfig{'send_mode'} = $in{'smtp'};
	if ($in{'port_def'}) {
		delete($mconfig{'smtp_port'});
		}
	else {
		$in{'port'} =~ /^\d+$/ || &error($text{'sendmail_eport'});
		$mconfig{'smtp_port'} = $in{'port'};
		}
	$mconfig{'smtp_ssl'} = $in{'ssl'};
	}

# Save login and password
if ($in{'login_def'}) {
	delete($mconfig{'smtp_user'});
	delete($mconfig{'smtp_pass'});
	}
else {
	$in{'login_user'} =~ /^\S+$/ || &error($text{'sendmail_elogin'});
	eval "use Authen::SASL";
	if ($@) {
		# Perl module missing
		&error(&text('sendmail_esasl',
			"/cpan/download.cgi?source=3&cpan=Authen::SASL&".
                        "mode=2&return=/$module_name/&returndesc=".
                        &urlize($text{'index_return'}),
			"Authen::SASL"));
		}
	$mconfig{'smtp_user'} = $in{'login_user'};
	$mconfig{'smtp_pass'} = $in{'login_pass'};
	}

# Save auth method
$mconfig{'smtp_auth'} = $in{'auth'};

# Save from address
if ($in{'from_def'}) {
	delete($mconfig{'webmin_from'});
	}
else {
	$in{'from'} =~ /^\S+$/ || &error($text{'sendmail_efrom'});
	$mconfig{'webmin_from'} = $in{'from'};
	}
$mconfig{'webmin_from_name'} = $in{'from_name'};

# Save to address
if ($in{'to_def'}) {
	delete($gconfig{'webmin_email_to'});
	}
else {
	$in{'to'} =~ /^\S+$/ || &error($text{'sendmail_etoaddr'});
	$gconfig{'webmin_email_to'} = $in{'to'};
	}

# Save URL for use in email
if ($in{'url_def'}) {
	delete($gconfig{'webmin_email_url'});
	}
else {
	my @p = &parse_http_url($in{'url'});
	$p[0] || &error($text{'sendmail_eurl'});
	$gconfig{'webmin_email_url'} = $in{'url'};
	}

&save_module_config(\%mconfig, "mailboxes");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");
&unlock_file($mailboxes::module_config_file);
&webmin_log("sendmail");
&redirect("");

