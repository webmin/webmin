#!/usr/local/bin/perl
# Start the Fail2Ban server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%text);
&error_setup($text{'start_err'});
my $err = &start_fail2ban_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("start");
&redirect("");
