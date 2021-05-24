#!/usr/local/bin/perl
# Enable two-factor authentication

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'twofactor_err'});
&get_usermin_miniserv_config(\%miniserv);
&foreign_require("cron");

# Validate inputs
if ($in{'twofactor_provider'}) {
	($prov) = grep { $_->[0] eq $in{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	$prov || &error($text{'twofactor_eprovider'});
	$vfunc = "webmin::validate_twofactor_apikey_".$in{'twofactor_provider'};
	$err = defined(&$vfunc) && &$vfunc(\%in, \%miniserv);
	&error($err) if ($err);
	}

# Save settings
&lock_file($usermin_miniserv_config);
$miniserv{'twofactor_provider'} = $in{'twofactor_provider'};
$miniserv{'twofactorfile'} ||= "$config{'usermin_dir'}/twofactor-users";
$miniserv{'twofactor_wrapper'} =
	"$config{'usermin_dir'}/twofactor/twofactor.pl";
&create_cron_wrapper($miniserv{'twofactor_wrapper'},
			       "twofactor", "twofactor.pl");
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();

&webmin_log("twofactor", undef, undef, \%in);
&redirect("");
