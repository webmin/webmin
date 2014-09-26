#!/usr/local/bin/perl
# Stop and then re-start the iSCSI server process

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text);
&error_setup($text{'restart_err'});
my $err = &restart_iscsi_tgtd();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("restart");
&redirect("");
