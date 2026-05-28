#!/usr/local/bin/perl
# Save a manually edited allowlisted GRUB 2 file.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParseMime();
&error_setup($text{'manual_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pmanual'}") if (!$access{'manual'});

# Re-check the allowlist on save; the form value is not trusted.
my $file = $in{'file'} || '';
&grub2_manual_file($file) || &error($text{'manual_efile'});
$in{'data'} = '' if (!defined($in{'data'}));
$in{'data'} =~ s/\r//g;

# Each file type gets its own validator before the locked write happens.
my $err = &save_manual_grub_file($file, $in{'data'});
&error(&text('manual_evalidate', $err)) if ($err);
&grub2_mark_regenerate_needed();
&webmin_log("manual", undef, $file);
&redirect("");
