#!/usr/local/bin/perl
# Display options specific to mobile devices

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'mobile_err'});

&lock_file($ENV{'MINISERV_CONFIG'});
&lock_file("$config_directory/config");
&get_miniserv_config(\%miniserv);

# Validate and store inputs
if ($in{'theme'} eq '*') {
	delete($miniserv{'mobile_preroot'});
	delete($gconfig{'mobile_theme'});
	}
else {
	$miniserv{'mobile_preroot'} = $in{'theme'};
	$gconfig{'mobile_theme'} = $in{'theme'};
	}
$miniserv{'mobile_nosession'} = $in{'nosession'};
$in{'agents'} =~ s/\r//g;
$miniserv{'mobile_agents'} = join("\t", split(/\n+/, $in{'agents'}));
$miniserv{'mobile_prefixes'} = $in{'prefixes'};

# Write out files
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

&reload_miniserv();
&webmin_log('mobile', undef, undef, \%in);
&redirect("");


