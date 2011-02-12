#!/usr/local/bin/perl
# delete_action.cgi
# Delete an existing action and remove it from all the runlevels

require './init-lib.pl';
&ReadParse();
$access{'bootup'} == 1 || &error($text{'save_ecannot'});

if ($in{type} == 0) {
	# Deleting a normal action
	foreach (&action_levels('S', $in{action})) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action($in{action}, $1, 'S');
		}
	foreach (&action_levels('K', $in{action})) {
		/^(\S+)\s+(\S+)\s+(\S+)$/;
		&delete_rl_action($in{action}, $1, 'K');
		}
	$file = &action_filename($in{action});
	}
elsif ($in{type} == 1) {
	# deleting an odd action
	$file = &runlevel_filename($in{runlevel}, $in{startstop},
				   $in{number}, $in{action});
	}
if (&has_command("insserv")) {
	&system_logged("insserv -r ".quotemeta($in{action}));
	}
&unlink_logged("/etc/init/$in{'action'}.conf");
&unlink_logged($file);
&webmin_log('delete', 'action', $in{'action'});
&redirect("");

