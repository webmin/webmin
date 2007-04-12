#!/usr/local/bin/perl
# save_users.cgi
# save user and group related sshd options

require './sshd-lib.pl';
&ReadParse();
&error_setup($text{'access_err'});
&lock_file($config{'sshd_config'});
$conf = &get_sshd_config();

if ($version{'type'} eq 'ssh') {
	if ($in{'allowh_def'}) {
		&save_directive("AllowHosts", $conf);
		}
	else {
		$in{'allowh'} =~ /\S/ || &error($text{'access_eallowh'});
		&save_directive("AllowHosts", $conf, $in{'allowh'});
		}

	if ($in{'denyh_def'}) {
		&save_directive("DenyHosts", $conf);
		}
	else {
		$in{'denyh'} =~ /\S/ || &error($text{'access_edenyh'});
		&save_directive("DenyHosts", $conf, $in{'denyh'});
		}
	}

$commas = $version{'type'} eq 'ssh' && $version{'number'} >= 3.2;
if ($in{'allowu_def'}) {
	&save_directive("AllowUsers", $conf);
	}
else {
	$in{'allowu'} =~ /\S/ || &error($text{'access_eallowu'});
	&save_directive("AllowUsers", $conf,
	    $commas ? join(",", split(/\s+/, $in{'allowu'})) : $in{'allowu'});
	}
if ($in{'denyu_def'}) {
	&save_directive("DenyUsers", $conf);
	}
else {
	$in{'denyu'} =~ /\S/ || &error($text{'access_edenyu'});
	&save_directive("DenyUsers", $conf,
	    $commas ? join(",", split(/\s+/, $in{'denyu'})) : $in{'denyu'});
	}

if ($in{'allowg_def'}) {
	&save_directive("AllowGroups", $conf);
	}
else {
	$in{'allowg'} =~ /\S/ || &error($text{'access_eallowg'});
	&save_directive("AllowGroups", $conf,
	    $commas ? join(",", split(/\s+/, $in{'allowg'})) : $in{'allowg'});
	}
if ($in{'denyg_def'}) {
	&save_directive("DenyGroups", $conf);
	}
else {
	$in{'denyg'} =~ /\S/ || &error($text{'access_edenyg'});
	&save_directive("DenyGroups", $conf,
	    $commas ? join(",", split(/\s+/, $in{'denyg'})) : $in{'denyg'});
	}

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&save_directive("SilentDeny", $conf, $in{'silent'} ? 'yes' : 'no');
	}

&flush_file_lines();
&unlock_file($config{'sshd_config'});
&webmin_log("access");
&redirect("");

