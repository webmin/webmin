#!/usr/local/bin/perl
# save_user.cgi
# Save other user options

require './spam-lib.pl';
&error_setup($text{'user_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("user");
&execute_before("user");
&lock_spam_files();
$conf = &get_config();

if ($in{'dns'} == 1) {
	&save_directives($conf, 'dns_available', [ 'yes' ], 1);
	}
elsif ($in{'dns'} == 0) {
	&save_directives($conf, 'dns_available', [ 'no' ], 1);
	}
elsif ($in{'dns'} == -1) {
	&save_directives($conf, 'dns_available', [ ], 1);
	}
else {
	local $test = "test";
	if ($in{'dnslist'}) {
		$test .= ": $in{'dnslist'}";
		}
	if ($config{'defaults'} && !$in{'dnslist'}) {
		&save_directives($conf, 'dns_available', [ ]);
		}
	else {
		&save_directives($conf, 'dns_available', [ $test ], 1);
		}
	}

&parse_opt($conf, "razor_timeout", \&check_timeout);

&parse_opt($conf, "dcc_path", \&check_path);
&parse_opt($conf, "dcc_body_max", \&check_max);
&parse_opt($conf, "dcc_timeout", \&check_timeout);
&parse_opt($conf, "dcc_fuz1_max", \&check_max);
&parse_opt($conf, "dcc_fuz2_max", \&check_max);
if (!&version_atleast(3)) {
	&parse_yes_no($conf, "dcc_add_header");
	}

&parse_opt($conf, "pyzor_path", \&check_path);
&parse_opt($conf, "pyzor_body_max", \&check_max);
&parse_opt($conf, "pyzor_timeout", \&check_timeout);
&parse_yes_no($conf, "pyzor_add_header");

&flush_file_lines();
&unlock_spam_files();
&execute_after("user");
&webmin_log("user");
&redirect($redirect_url);

sub check_timeout
{
$_[0] =~ /^\d+$/ || &error(&text('user_etimeout', $_[0]));
}

sub check_path
{
$_[0] =~ /^\// && -r $_[0] || &error(&text('user_epath', $_[0]));
}

sub check_max
{
$_[0] =~ /^\d+$/ || &error(&text('user_emax', $_[0]));
}

