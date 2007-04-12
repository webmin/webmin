#!/usr/local/bin/perl
# save_conf.cgi
# Save configuration options

require './heartbeat-lib.pl';
&ReadParse();
@conf = &get_ha_config();
&error_setup($text{'conf_err'});

# Parse and validate inputs
for($i=0; defined($in{"serial_$i"}); $i++) {
	push(@serials, $in{"serial_$i"}) if ($in{"serial_$i"});
	}
&save_directive(\@conf, 'serial', \@serials );

if ($in{'baud_def'}) {
	&save_directive(\@conf, 'baud', [ ]);
	}
else {
	$in{'baud'} =~ /^\d+$/ || &error($text{'conf_ebaud'});
	&save_directive(\@conf, 'baud', [ $in{'baud'} ]);
	}

# changed (Christof Amelunxen, 22.08.2003)
# udp now bcast
if ($in{'bcasts_def'}) {
	&save_directive(\@conf, 'bcast', [ ]);
	}
else {
	@bcasts = split(/\s+/, $in{'bcasts'});
	foreach $b (@bcasts) {
		$b =~ /^\S+\d+$/ || &error(&text('conf_ebcastif', $b));
		}
	@bcasts || &error($text{'conf_ebcasts'});
	&save_directive(\@conf, 'bcast', \@bcasts);
	}

if ($in{'udpport_def'}) {
	&save_directive(\@conf, 'udpport', [ ]);
	}
else {
	$in{'udpport'} =~ /^\d+$/ || &error($text{'conf_eudpport'});
	&save_directive(\@conf, 'udpport', [ $in{'udpport'} ]);
	}

if ($in{'mcast_def'}) {
	&save_directive(\@conf, 'mcast', [ ]);
	}
else {
	$in{'mcast_dev'} =~ /^\S+\d+$/ || &error($text{'conf_emcast_dev'});
	&check_ipaddress($in{'mcast_ip'}) || &error($text{'conf_emcast_ip'});
	$in{'mcast_port'} =~ /^\d+$/ || &error($text{'conf_emcast_port'});
	$in{'mcast_ttl'} =~ /^\d+$/ || &error($text{'conf_emcast_ttl'});
	&save_directive(\@conf, 'mcast', [ join(" ",
		$in{'mcast_dev'}, $in{'mcast_ip'}, $in{'mcast_port'},
		$in{'mcast_ttl'}, $in{'mcast_loop'}) ] );
	}

if ($in{'keepalive_def'}) {
	&save_directive(\@conf, 'keepalive', [ ]);
	}
else {
	$in{'keepalive'} =~ /^\d+$/ || &error($text{'conf_ekeepalive'});
	&save_directive(\@conf, 'keepalive', [ $in{'keepalive'} ]);
	}

if ($in{'deadtime_def'}) {
	&save_directive(\@conf, 'deadtime', [ ]);
	}
else {
	$in{'deadtime'} =~ /^\d+$/ || &error($text{'conf_edeadtime'});
	&save_directive(\@conf, 'deadtime', [ $in{'deadtime'} ]);
	}

if ($in{'watchdog_def'}) {
	&save_directive(\@conf, 'watchdog', [ ]);
	}
else {
	-r $in{'watchdog'} || &error($text{'conf_ewatchdog'});
	&save_directive(\@conf, 'watchdog', [ $in{'watchdog'} ]);
	}

@node = split(/\s+/, $in{'node'});
@node || &error($text{'conf_enonode'});
$uname = `uname -n 2>/dev/null`;
$uname =~ s/\r|\n//g;
foreach $n (@node) {
	$found++ if ($n eq $uname);
	}
!$uname || $found || &error(&text('conf_ethisnode', "<tt>$uname</tt>"));
&save_directive(\@conf, 'node', \@node);

if ($in{'logfile_def'}) {
	&save_directive(\@conf, 'logfile', [ ]);
	}
else {
	$in{'logfile'} =~ /^\S+$/ || &error($text{'conf_elogfile'});
	&save_directive(\@conf, 'logfile', [ $in{'logfile'} ]);
	}

if ($in{'logfacility_def'}) {
	&save_directive(\@conf, 'logfacility', [ ]);
	}
else {
	&save_directive(\@conf, 'logfacility', [ $in{'logfacility'} ]);
	}

if ($in{'initdead_def'}) {
	&save_directive(\@conf, 'initdead', [ ]);
	}
else {
	$in{'initdead'} =~ /^\d+$/ || &error($text{'conf_einitdead'});
	$in{'deadtime_def'} || $in{'initdead'} >= $in{'deadtime'}*2 ||
		&error($text{'conf_einitdead2'});
	&save_directive(\@conf, 'initdead', [ $in{'initdead'} ]);
	}

# save nice failback behaviour
if (&version_atleast(1, 2, 0)) {
	# New-style option
	if ($in{'auto_failback'}) {
		&save_directive(\@conf, 'auto_failback',
			        [ $in{'auto_failback'} ]);
		}
	else {
		&save_directive(\@conf, 'auto_failback', [ ]);
		}
	}
else {
	# Old-style option
	if ($in{'nice_failback_def'}) {
		&save_directive(\@conf,'nice_failback',[ 'on' ]);
		}
	else {
		&save_directive(\@conf,'nice_failback', [ 'off' ]);
		}
	}
	

&flush_file_lines();
&redirect("");

