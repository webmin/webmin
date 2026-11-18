#!/usr/local/bin/perl
# Re-start Usermin to clear blocks

require './usermin-lib.pl';
$access{'blocked'} || &error($text{'acl_ecannot'});
&restart_usermin_miniserv();
&redirect("");


