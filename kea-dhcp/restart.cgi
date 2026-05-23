#!/usr/local/bin/perl
# Restart Kea services.

use strict;
use warnings;
require './kea-dhcp-lib.pl';
our %text;
&error_setup($text{'eacl_aviol'});
&kea_assert_acl('apply');

# Restart/reload applies the saved configuration for all Kea services.
&error_setup($text{'restart_fail'});
my $err = &kea_run_action('restart');
&error($err) if ($err);
&webmin_log("apply");
&redirect("");
