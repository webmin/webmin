#!/usr/local/bin/perl
# kill_proc.cgi
# Send a signal to a process

require './proc-lib.pl';
&ReadParse();
&switch_acl_uid();
&error_setup(&text('kill_err', $in{signal}, $in{pid}));
foreach $s ('KILL', 'TERM', 'HUP', 'STOP', 'CONT') {
	$in{'signal'} = $s if ($in{$s});
	}

%pinfo = &process_info($in{pid});
&can_edit_process($pinfo{'user'}) || &error($text{'kill_ecannot'});
if (&kill_logged($in{signal}, $in{pid})) {
	$in{'args0'} = $pinfo{'args'};
	&webmin_log("kill", undef, undef, \%in);
	sleep(1);
	if (&process_info($in{pid})) {
		# still around.. return to process info
		&redirect("edit_proc.cgi?$in{pid}");
		}
	else {
		# gone case .. return to list
		&redirect("index.cgi");
		}
	}
else {
	# failed to send signal
	&error("$!");
	}

