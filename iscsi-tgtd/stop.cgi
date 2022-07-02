#!/usr/local/bin/perl
# Kill the running iscsi server process

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-tgtd-lib.pl';
our (%text);
&error_setup($text{'stop_err'});
my $err = &stop_iscsi_tgtd();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");
