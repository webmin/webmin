#!/usr/local/bin/perl
# Stop the Fail2Ban server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%text);
&error_setup($text{'stop_err'});
my $err = &stop_fail2ban_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("stop");
&redirect("");
