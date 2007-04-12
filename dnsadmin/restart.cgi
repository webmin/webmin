#!/usr/local/bin/perl
# restart.cgi
# Restart the running named

require './dns-lib.pl';
&ReadParse();
$whatfailed = "Failed to restart named";
&kill_logged('HUP', $in{'pid'}) ||
	&error("Failed to signal process $in{'pid'} : $!");
&webmin_log("apply");
&redirect("");

