#!/usr/local/bin/perl
# restart.cgi
# Send a SIGHUP to apache

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'restart_err'});

$access{'apply'} || &error($text{'restart_ecannot'});
$conf = &get_config();

if ($config{'test_config'}) {
	$err = &test_config();
	&error("<pre>".&html_escape($err)."</pre>") if ($err);
	}
$err = &restart_apache();
&error($err) if ($err);

# Check if restart was successful.. some config file error may have caused it
# to silently fail
for($i=0; $i<5; $i++) {
	if (&is_apache_running()) {
		$running = 1;
		last;
		}
	sleep(1);
	}
if (!$running) {
	# Not running..  find out why
	$errorlogstr = &find_directive_struct("ErrorLog", $conf);
	$errorlog = $errorlogstr ? $errorlogstr->{'words'}->[0]
				 : "logs/error_log";
	if ($errorlog eq 'syslog' || $errorlog =~ /^\|/) {
		&error($text{'restart_eunknown'});
		}
	else {
		$errorlog = &server_root($errorlog, $conf);
		$out = `tail -5 $errorlog`;
		&error("<pre>$out</pre>");
		}
	}
&webmin_log("apply");
&redirect($in{'redir'});

