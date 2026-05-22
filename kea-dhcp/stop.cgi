#!/usr/local/bin/perl
# Stop Kea services.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
our %text;
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('apply');

# The header action buttons operate on all configured Kea components together.
&error_setup($text{'stop_fail'});
my $err = &kea_run_action('stop');
&error($err) if ($err);
&webmin_log("stop");
&redirect("");
