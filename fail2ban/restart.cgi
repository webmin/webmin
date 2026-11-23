#!/usr/local/bin/perl
# Restart the Fail2Ban server

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'restart_err'});
my $err = &restart_fail2ban_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("restart");
# Return to the referring page or module index
&redirect(&get_referer_relative() || "");
