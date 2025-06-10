#!/usr/local/bin/perl
# Display options specific to mobile devices

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'mobile_err'});

&lock_file($usermin_miniserv_config);
&lock_file("$config{'usermin_dir'}/config");
&get_usermin_miniserv_config(\%miniserv);
&get_usermin_config(\%uconfig);

# Validate and store inputs
if ($in{'theme'} eq '*') {
	delete($miniserv{'mobile_preroot'});
	delete($uconfig{'mobile_theme'});
	}
else {
	$miniserv{'mobile_preroot'} = $in{'theme'};
	$uconfig{'mobile_theme'} = $in{'theme'};
	}
$miniserv{'mobile_nosession'} = $in{'nosession'};
$in{'agents'} =~ s/\r//g;
$miniserv{'mobile_agents'} = join("\t", split(/\n+/, $in{'agents'}));
$miniserv{'mobile_prefixes'} = $in{'prefixes'};

# Write out files
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&put_usermin_config(\%uconfig);
&unlock_file("$config{'usermin_dir'}/config");

&reload_usermin_miniserv();
&webmin_log('mobile', undef, undef, \%in);
&redirect("");


