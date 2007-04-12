#!/usr/local/bin/perl
# Save DAV server options

require './usermin-lib.pl';
&error_setup($text{'dav_err'});
&get_usermin_miniserv_config(\%miniserv);
&ReadParse();

if ($in{'path_def'}) {
	delete($miniserv{'davpaths'});
	}
else {
	$in{'path'} =~ /^\/\S/ || &error($text{'dav_epath'});
	$miniserv{'davpaths'} = $in{'path'};
	}

if ($in{'root_def'} == 0) {
	delete($miniserv{'dav_root'});
	}
elsif ($in{'root_def'} == 1) {
	$miniserv{'dav_root'} = '*';
	}
else {
	-d $in{'root'} || &error($text{'dav_eroot'});
	$miniserv{'dav_root'} = $in{'root'};
	}

if ($in{'users_def'}) {
	delete($miniserv{'dav_users'});
	}
else {
	$in{'users'} =~ /\S/ || &error($text{'dav_eusers'});
	$miniserv{'dav_users'} = join(" ", split(/\s+/, $in{'users'}));
	}

if (!defined($miniserv{'dav_remoteuser'})) {
	$miniserv{'dav_remoteuser'} = 1;
	}

# Update config
&lock_file($usermin_miniserv_config);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();
&webmin_log("dav");
&redirect("");

