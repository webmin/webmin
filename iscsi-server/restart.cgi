#!/usr/local/bin/perl
# Stop and then re-start the iSCSI server process

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text);
&error_setup($text{'restart_err'});
my $err = &restart_iscsi_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("restart");
&redirect("");
