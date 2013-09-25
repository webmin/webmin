#!/usr/local/bin/perl
# Enable two-factor authentication

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'twofactor_err'});

# Validate inputs
if ($in{'twofactor_provider'}) {
	($got) = grep { $_->[0] eq $in{'twofactor_provider'} }
		      &list_twofactor_providers();
	$got || &error($text{'twofactor_eprovider'});
	$in{'twofactor_apikey'} =~ /^\S+$/ ||
		&error($text{'twofactor_eapikey'});
	$vfunc = "validate_twofactor_apikey_".$in{'twofactor_provider'};
	$err = defined(&$vfunc) && &$vfunc($in{'twofactor_apikey'});
	&error($err) if ($err);
	}

# Save settings
&lock_file($ENV{'MINISERV_CONFIG'});
&get_miniserv_config(\%miniserv);
$miniserv{'twofactor_provider'} = $in{'twofactor_provider'};
$miniserv{'twofactor_apikey'} = $in{'twofactor_apikey'};

&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("twofactor", undef, undef, \%in);
