#!/usr/local/bin/perl
# start.cgi
# Start apache with the server root from the config files

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'start_err'});
$access{'stop'} || &error($text{'start_ecannot'});
$err = &start_apache();
&error($err) if ($err);
&webmin_log("start");
&redirect($in{'redir'});

