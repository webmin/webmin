#!/usr/local/bin/perl
# restart.cgi
# Restart the running squid process

require './squid-lib.pl';
&ReadParse();
&error_setup($text{'restart_ftrs'});
$err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect($in{'redir'});

