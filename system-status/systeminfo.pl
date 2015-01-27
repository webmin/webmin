#!/usr/local/bin/perl
# Collect various pieces of general system information, for display by themes
# on their status pages. Run every 5 mins from Cron.

use strict;
use warnings;
package system_status;
require './system-status-lib.pl';
&scheduled_collect_system_info();

