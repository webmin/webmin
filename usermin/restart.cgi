#!/usr/local/bin/perl
# Re-start Webmin

require './usermin-lib.pl';
$access{'stop'} || &error($text{'stop_ecannot'});
&restart_usermin_miniserv();
&redirect("");


