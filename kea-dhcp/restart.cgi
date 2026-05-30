#!/usr/local/bin/perl
# Restart Kea services.

use strict;
use warnings;
require './kea-dhcp-lib.pl';    ## no critic
our %text;
&error_setup($text{'eacl_aviol'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_papply'}") if (!$access{'apply'});

# Restart/reload applies the saved configuration for all Kea services.
&error_setup($text{'restart_fail'});
my $err = &kea_run_action('restart');
&error($err) if ($err);
&webmin_log("apply");
&redirect("");
