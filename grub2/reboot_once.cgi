#!/usr/local/bin/perl
# Set the one-time next GRUB 2 boot entry.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'runtime_err'});
&grub2_assert_acl('runtime');

# Runtime commands operate on the parsed generated menu index shown on index.cgi.
my $entry = &grub2_entry_by_index($in{'idx'});
&error($text{'runtime_eentry'}) if (!$entry);
# The helper validates the selector before invoking grub-reboot.
my $err = &grub2_run_entry_command('reboot_once_cmd', $entry);
&error($err) if ($err);
my $selector = &grub2_entry_selector($entry);
&webmin_log("once", undef, $selector);
&redirect("");
