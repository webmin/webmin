#!/usr/local/bin/perl
# save_options.cgi
# Save PPP server options

require './pptp-server-lib.pl';
$access{'options'} || &error($text{'options_ecannot'});
&error_setup($text{'options_err'});
&ReadParse();

$conf = &get_config();
$option = &find_conf("option", $conf);
$option ||= $config{'ppp_options'};
&lock_file($option);
@opts = &parse_ppp_options($option);

# Validate inputs
$in{'mtu_def'} || $in{'mtu'} =~ /^\d+$/ || &error($text{'options_emtu'});
$in{'mru_def'} || $in{'mru'} =~ /^\d+$/ || &error($text{'options_emru'});
$in{'name_def'} || $in{'name'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error($text{'options_ename'});

# Save options
&save_ppp_option(\@opts, $option, "proxyarp",
		 $in{'proxyarp'} ? { 'name' => 'proxyarp' } : undef);
&save_ppp_option(\@opts, $option, "lock",
		 $in{'lock'} ? { 'name' => 'lock' } : undef);
&save_ppp_option(\@opts, $option, "mtu",
		 $in{'mtu_def'} ? undef : { 'name' => 'mtu',
					    'value' => $in{'mtu'} });
&save_ppp_option(\@opts, $option, "mru",
		 $in{'mru_def'} ? undef : { 'name' => 'mru',
					    'value' => $in{'mru'} });

if ($in{'auth'} == 0) {
	&save_ppp_option(\@opts, $option, "auth", undef);
	&save_ppp_option(\@opts, $option, "noauth", undef);
	}
elsif ($in{'auth'} == 1) {
	&save_ppp_option(\@opts, $option, "auth", undef);
	&save_ppp_option(\@opts, $option, "noauth", { 'name' => 'noauth' });
	}
else {
	&save_ppp_option(\@opts, $option, "noauth", undef);
	&save_ppp_option(\@opts, $option, "auth", { 'name' => 'auth' });
	}
&parse_auth("pap");
&parse_auth("chap");
&save_ppp_option(\@opts, $option, "login",
		 $in{'login'} ? { 'name' => 'login' } : undef);
&save_ppp_option(\@opts, $option, "name",
		$in{'name_def'} ? undef : { 'name' => 'name',
					    'value' => $in{'name'} });

&foreign_require("pptp-client", "pptp-client-lib.pl");
&pptp_client::parse_mppe_options(\@opts, $option);

if (&pptp_client::mppe_support() == 1) {
	&parse_auth("mschap");
	&parse_auth("mschap-v2");
	}
else {
	&parse_auth("chapms");
	&parse_auth("chapms-v2");
	}

# All done
&flush_file_lines();
&unlock_file($option);
&webmin_log("options", undef, undef, \%in);
&redirect("");

# parse_auth(name)
sub parse_auth
{
local $a = $_[0];
if ($in{$a} == 2) {
	&save_ppp_option(\@opts, $option, "require-$a",
			 { 'name' => "require-$a" });
	&save_ppp_option(\@opts, $option, "refuse-$a", undef);
	}
elsif ($in{$a} == 1) {
	&save_ppp_option(\@opts, $option, "require-$a", undef);
	&save_ppp_option(\@opts, $option, "refuse-$a", undef);
	}
else {
	&save_ppp_option(\@opts, $option, "require-$a", undef);
	&save_ppp_option(\@opts, $option, "refuse-$a",
			 { 'name' => "refuse-$a" });
	}
}
