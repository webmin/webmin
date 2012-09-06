#!/usr/local/bin/perl
# Start the iSCSI server process

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text);
&error_setup($text{'start_err'});
my $err = &start_iscsi_server();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("start");
&redirect("");
