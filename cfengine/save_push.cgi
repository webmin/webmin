#!/usr/local/bin/perl
# save_push.cgi
# Save cfrun options

require './cfengine-lib.pl';
&ReadParse();
&error_setup($text{'push_err'});

# Validate and parse inputs
($oldhosts, $opts) = &get_cfrun_hosts();
$in{'domain'} =~ /^[A-Za-z0-9\.\-]+$/ || &error($text{'push_edomain'});
$opts->{'domain'} = $in{'domain'};
$opts->{'access'} = join(",", split(/\s+/, $in{'access'}));
for($i=0; defined($in{"host_$i"}); $i++) {
	next if (!$in{"host_$i"});
	&to_ipaddress($in{"host_$i"}) ||
		&error(&text('push_ehost', $in{"host_$i"}));
	&to_ipaddress($in{"host_$i"}) ne &to_ipaddress(&get_system_hostname())||
		&error(&text('push_ethis', $in{"host_$i"}));
	push(@hosts, [ $in{"host_$i"}, $in{"opts_$i"} ] );
	}

# Write to file
&lock_file($cfrun_hosts);
&save_cfrun_hosts(\@hosts, $opts);
&unlock_file($cfrun_hosts);
&webmin_log("push");

&redirect("");

