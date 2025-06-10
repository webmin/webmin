#!/usr/local/bin/perl
# save_auth.cgi
# Save authentication settings

require './heartbeat-lib.pl';
&ReadParse();
&error_setup($text{'auth_err'});

$conf = &get_auth_config();
$conf->{'auth'} = [ $in{'auth'} ];
$i = 1;
foreach $k ('crc', 'sha1', 'md5') {
	if ($k eq 'crc') {
		$conf->{$i} = [ $k ];
		}
	else {
		$in{'auth'} != $i || $in{$k} =~ /^\S+$/ ||
			&error($text{"auth_e$k"});
		$conf->{$i} = [ $k, $in{$k} ];
		}
	$i++;
	}
&save_auth_config($conf);
&redirect("");

