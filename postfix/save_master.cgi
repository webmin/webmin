#!/usr/local/bin/perl
# Create, update or delete a server process

require './postfix-lib.pl';
$access{'master'} || &error($text{'master_ecannot'});
&ReadParse();
&error_setup($text{'master_err'});
$master = &get_master_config();
if ($in{'new'}) {
	$prog = { };
	}
else {
	($prog) = grep { $_->{'name'} eq $in{'old'} &&
			 $_->{'type'} eq $in{'oldtype'} &&
			 $_->{'enabled'} == $in{'oldenabled'} } @$master;
	$prog || &error($text{'master_egone'});
	}
&lock_file($config{'postfix_master'});

if ($in{'delete'}) {
	# Just delete this one
	&delete_master($prog);
	}
else {
	# Validate and store inputs
	$prog->{'type'} = $in{'type'};
	$prog->{'enabled'} = $in{'enabled'};
	$in{'name'} =~ /^\S+$/ || &error($text{'master_ename'});
	if (!$in{'host_def'}) {
		&to_ipaddress($in{'host'}) || &error($text{'master_ehost'});
		$in{'type'} eq 'inet' || &error($text{'master_einet'});
		$prog->{'name'} = $in{'host'}.":".$in{'name'};
		}
	else {
		$prog->{'name'} = $in{'name'};
		}
	$in{'command'} =~ /^\S/ || &error($text{'master_ecommand'});
	$prog->{'command'} = $in{'command'};
	$prog->{'private'} = $in{'private'};
	$prog->{'unpriv'} = $in{'unpriv'};
	$prog->{'chroot'} = $in{'chroot'};
	if ($in{'wakeup'} == 0) {
		$prog->{'wakeup'} = '-';
		}
	elsif ($in{'wakeup'} == 1) {
		$prog->{'wakeup'} = '0';
		}
	else {
		$in{'wtime'} =~ /^\d+$/ || &error($text{'master_ewakeup'});
		$prog->{'wakeup'} = $in{'wtime'}.($in{'wused'} ? "?" : "");
		}
	if ($in{'maxprocs'} == 0) {
		$prog->{'maxprocs'} = '-';
		}
	elsif ($in{'maxprocs'} == 1) {
		$prog->{'maxprocs'} = '0';
		}
	else {
		$in{'procs'} =~ /^\d+$/ || &error($text{'master_emaxprocs'});
		$prog->{'maxprocs'} = $in{'procs'};
		}

	# Check for clash by name and type, but only between enabled servers
	if ($in{'enabled'}) {
		if ($in{'new'} || $in{'name'} ne $in{'old'} ||
				  $in{'type'} ne $in{'oldtype'}) {
			($clash) = grep { $_->{'name'} eq $in{'name'} &&
					  $_->{'type'} eq $in{'type'} &&
					  $_->{'enabled'} } @$master;
			$clash && &error($text{'master_eclash'});
			}
		}

	# Save or update
	if ($in{'new'}) {
		&create_master($prog);
		}
	else {
		&modify_master($prog);
		}
	}
&unlock_file($config{'postfix_master'});

# Apply config
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "master", $prog->{'name'}, $prog);
&redirect("master.cgi");

