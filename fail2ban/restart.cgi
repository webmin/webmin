#!/usr/local/bin/perl
# Restart the Fail2Ban server

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%text);
&error_setup($text{'restart_err'});
my $err = &restart_fail2ban_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("restart");
&redirect("");
