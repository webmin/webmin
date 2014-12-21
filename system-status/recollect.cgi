#!/usr/local/bin/perl
# Refresh background collected info

use strict;
use warnings;
require './system-status-lib.pl';
&scheduled_collect_system_info();
&redirect($ENV{'HTTP_REFERER'});
