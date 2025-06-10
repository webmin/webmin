#!/usr/local/bin/perl
# stop.cgi
# Stop the running apache server

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'stop_err'});

$access{'stop'} || &error($text{'stop_ecannot'});
$err = &stop_apache();
&error($err) if ($err);
sleep(1);
&webmin_log("stop");
&redirect($in{'redir'});

