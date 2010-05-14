#!/usr/local/bin/perl
# Collect various pieces of general system information, for display by themes
# on their status pages. Run every 5 mins from Cron.

package system_status;
$main::no_acl_check++;
require './system-status-lib.pl';
&scheduled_collect_system_info();

