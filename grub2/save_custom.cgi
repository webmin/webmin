#!/usr/local/bin/perl
# Save a custom GRUB 2 menu entry.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'custom_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pmanual'}") if (!$access{'manual'});

# A missing index means create; a present one must address a parsed entry.
my $idx = defined($in{'idx'}) && $in{'idx'} ne '' ? $in{'idx'} : undef;
if (defined($idx) && $idx !~ /^\d+\z/) {
	&error($text{'custom_eentry'});
	}
# Normalize absent fields before validation so empty strings mean intentional.
foreach my $field (qw(title id body)) {
	$in{$field} = "" if (!defined($in{$field}));
	}
$in{'body'} =~ s/\r//g;
# The library validates GRUB script balance before rewriting the custom file.
my $err = &grub2_save_custom_entry($idx, $in{'title'}, $in{'id'},
				   $in{'body'});
&error($err) if ($err);
&grub2_mark_regenerate_needed();
&webmin_log(defined($idx) ? "custom_modify" : "custom_create",
	    undef, $in{'title'});
&redirect("index.cgi?mode=custom");
