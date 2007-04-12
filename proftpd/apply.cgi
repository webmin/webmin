#!/usr/local/bin/perl
# apply.cgi
# Apply config file changes with a HUP signal

require './proftpd-lib.pl';
&ReadParse();
&error_setup($text{'apply_err'});
if ($config{'test_config'}) {
	$err = &test_config();
	&error("<pre>$err</pre>") if ($err);
	}
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect($in{'redir'});

