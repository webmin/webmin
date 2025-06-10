#!/usr/local/bin/perl
# Kill the running iscsi server process

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text);
&error_setup($text{'stop_err'});
my $err = &stop_iscsi_server();
&error($err) if ($err);
&webmin_log("stop");
&redirect("");
