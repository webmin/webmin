#!/usr/local/bin/perl
# apply.cgi
# Apply changes to the heartbeat process

require './heartbeat-lib.pl';
&ReadParse();
&error_setup($text{'apply_err'});
$err = &apply_configuration();
&error($err) if ($err);
&redirect("");

