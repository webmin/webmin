#!/usr/local/bin/perl
# Refresh background collected info

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './system-status-lib.pl';
&scheduled_collect_system_info('manual');
&redirect($ENV{'HTTP_REFERER'});
