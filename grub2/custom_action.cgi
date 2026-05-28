#!/usr/local/bin/perl
# Apply an action to selected custom GRUB 2 entries.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'custom_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pmanual'}") if (!$access{'manual'});

# Per-row up/down links post an index and direction directly.
if (defined($in{'idx'}) || defined($in{'dir'})) {
	defined($in{'idx'}) && $in{'idx'} =~ /^\d+\z/ ||
		&error($text{'custom_eentry'});
	# Keep movement inside one submenu by leaving it to the library helper.
	defined($in{'dir'}) && $in{'dir'} =~ /^(up|down)\z/ ||
		&error($text{'custom_emove'});
	my $err = &grub2_move_custom_entry($in{'idx'}, $in{'dir'});
	&error($err) if ($err);
	&grub2_mark_regenerate_needed();
	&webmin_log("custom_move", undef, $in{'idx'});
	&redirect("index.cgi?mode=custom");
	}

# Checked-table actions can receive duplicate browser values; collapse them.
my @selected = split(/\0/, defined($in{'d'}) ? $in{'d'} : "");
my %seen;
@selected = grep { defined($_) && $_ ne '' && !$seen{$_}++ } @selected;

my $err;
# Delete accepts multiple selected entries and removes them in one rewrite.
if ($in{'delete'}) {
	@selected || &error($text{'delete_enone'});
	$err = &grub2_delete_custom_entry_indexes(@selected);
	&error($err) if ($err);
	&grub2_mark_regenerate_needed();
	&webmin_log("custom_delete", undef, scalar(@selected));
	}
elsif ($in{'move_up'} || $in{'move_down'}) {
	# Bulk move buttons are only safe for one entry at a time.
	@selected == 1 || &error($text{'custom_eone'});
	$err = &grub2_move_custom_entry($selected[0],
		$in{'move_up'} ? "up" : "down");
	&error($err) if ($err);
	&grub2_mark_regenerate_needed();
	&webmin_log("custom_move", undef, $selected[0]);
	}
else {
	&error($text{'runtime_eaction'});
	}
&redirect("index.cgi?mode=custom");
