#!/usr/local/bin/perl
# Start Kea services.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
our %text;
&error_setup($text{'eacl_aviol'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_papply'}") if (!$access{'apply'});

# The header action buttons operate on all configured Kea components together.
&error_setup($text{'start_fail'});
my $err = &kea_run_action('start');
&error($err) if ($err);
&webmin_log("start");
&redirect("");
