#!/usr/local/bin/perl
# Start the iSCSI server process

use strict;
use warnings;
require './iscsi-tgtd-lib.pl';
our (%text);
&error_setup($text{'start_err'});
my $err = &start_iscsi_tgtd();
&error("<tt>".&html_escape($err)."</tt>") if ($err);
&webmin_log("start");
&redirect("");
