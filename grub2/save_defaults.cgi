#!/usr/local/bin/perl
# Save common GRUB 2 defaults.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'defaults_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pedit'}") if (!$access{'edit'});

# Capture both the current defaults file and generated entries for validation.
my $current = &read_grub_defaults();
my $current_values = $current->{'values'};
my @entries = &grub2_boot_entries();
my %updates;
# Default entries must come from the selector, except for the preserved value.
$in{'default'} = '' if (!defined($in{'default'}));
$in{'default'} =~ /[\r\n\0]/ && &error($text{'defaults_edefault'});
&error($text{'defaults_edefault_choice'})
	if (!&valid_default_entry_value(
		$in{'default'}, $current_values->{'GRUB_DEFAULT'}, \@entries));
$updates{'GRUB_DEFAULT'} = $in{'default'} if ($in{'default'} ne '');

my %styles = map { $_ => 1 } ('', qw(menu hidden countdown));
&error($text{'defaults_etimeout_style'})
	if (!defined($in{'timeout_style'}) || !$styles{$in{'timeout_style'}});
$updates{'GRUB_TIMEOUT_STYLE'} =
	$in{'timeout_style'} eq '' ? undef : $in{'timeout_style'};

# Empty timeout removes the local override; otherwise GRUB accepts -1 or more.
if (defined($in{'timeout'}) && $in{'timeout'} ne '') {
	$in{'timeout'} =~ /^-?\d+\z/ && $in{'timeout'} >= -1
		|| &error($text{'defaults_etimeout'});
	$updates{'GRUB_TIMEOUT'} = $in{'timeout'};
	}
else {
	$updates{'GRUB_TIMEOUT'} = undef;
	}

# Kernel command-line values are single-line shell assignment values.
foreach my $field (
	[ 'cmdline_default', 'GRUB_CMDLINE_LINUX_DEFAULT',
	  $text{'defaults_cmdline_default'} ],
	[ 'cmdline', 'GRUB_CMDLINE_LINUX', $text{'defaults_cmdline'} ],
    )
{
	my ($input, $key, $label) = @$field;
	$in{$input} = '' if (!defined($in{$input}));
	$in{$input} =~ /[\r\n\0]/ && &error(&text('defaults_ecmdline', $label));
	$updates{$key} = $in{$input} eq '' ? undef : $in{$input};
	}

# Boolean GRUB defaults keep their tri-state UI: inherit, true, or false.
foreach my $field (
	[ 'disable_recovery', 'GRUB_DISABLE_RECOVERY',
	  $text{'defaults_disable_recovery'} ],
	[ 'disable_os_prober', 'GRUB_DISABLE_OS_PROBER',
	  $text{'defaults_disable_os_prober'} ],
    )
{
	my ($input, $key, $label) = @$field;
	$in{$input} = '' if (!defined($in{$input}));
	if ($in{$input} eq '') {
		$updates{$key} = undef;
		}
	elsif ($in{$input} =~ /^(true|false)\z/) {
		$updates{$key} = $in{$input};
		}
	else {
		&error(&text('defaults_ebool', $label));
		}
	}

my $err = &save_grub_defaults_values(\%updates);
&error(&text('manual_evalidate', $err)) if ($err);

# BLS rescue entries are real files, so restore them before changing BLS args.
my $disable_bls_rescue =
	(($updates{'GRUB_DISABLE_RECOVERY'} || '') eq 'true') ? 1 : 0;
my $can_handle_bls_rescue =
	&grub2_has_bls_rescue_entries(\@entries) ||
	&grub2_disabled_bls_rescue_files();
my $bls_rescue_err;
if (!$disable_bls_rescue) {
	$bls_rescue_err = &grub2_set_bls_rescue_disabled(0);
	# Refresh entry data after restores so grubby sees current BLS files.
	@entries = &grub2_boot_entries() if (!$bls_rescue_err);
	}

# On BLS systems, grubby applies kernel arg deltas to existing boot entries.
my %bls_args_updated;
my $bls_err;
if (&grub2_bls_update_available(\@entries)) {
	my @locked_bls_files = &lock_bls_update_files(
		$current_values, \%updates, \@entries);
	($bls_err, %bls_args_updated) = &update_bls_kernel_args(
		$current_values, \%updates, \@entries);
	&unlock_bls_update_files(@locked_bls_files);
	}
if (!$bls_err && !$bls_rescue_err && $disable_bls_rescue) {
	# Hide rescue files after grubby has had a chance to update normal entries.
	$bls_rescue_err = &grub2_set_bls_rescue_disabled(1, \@entries);
	}
$bls_args_updated{'GRUB_DISABLE_RECOVERY'} = 1
	if (!$bls_rescue_err && $can_handle_bls_rescue &&
	    !&grub2_has_non_bls_recovery_entries(\@entries));
&grub2_mark_regenerate_needed()
	if (&grub2_defaults_updates_need_generate(
		$current_values, \%updates, \%bls_args_updated));
&webmin_log("defaults");
&error($bls_err) if ($bls_err);
&error($bls_rescue_err) if ($bls_rescue_err);
&redirect("index.cgi");

# valid_default_entry_value(value, current-value, &entries)
# Returns true if a posted default entry came from the detected selector.
sub valid_default_entry_value
{
my ($value, $current, $entries) = @_;
return 1 if (!defined($value) || $value eq '');
$current = '0' if (!defined($current) || $current eq '');
return 1 if ($value eq 'saved');
return 1 if ($value eq $current);
foreach my $entry (@$entries) {
	my $selector = &grub2_entry_selector($entry);
	return 1 if (defined($selector) && $selector eq $value);
	}
return 0;
}

# update_bls_kernel_args(&old-values, &updates, &entries)
# Applies changed kernel option defaults to existing BLS entries.
sub update_bls_kernel_args
{
my ($old_values, $updates, $entries) = @_;
my %updated;
foreach my $field (
	[ 'GRUB_CMDLINE_LINUX', undef ],
	[ 'GRUB_CMDLINE_LINUX_DEFAULT',
	  [ &grub2_bls_kernel_arg_targets($entries, 0) ] ],
    )
{
	my ($key, $targets) = @$field;
	my ($remove, $add) =
		&grub2_kernel_args_delta($old_values->{$key}, $updates->{$key});
	# No delta means this defaults field can be ignored for BLS updates.
	next if (!@$remove && !@$add);
	next if (defined($targets) && !@$targets);
	my $err = &grub2_update_bls_kernel_args(
		$old_values->{$key}, $updates->{$key}, $targets);
	if ($err) {
		# A partial grubby failure falls back to regeneration when needed.
		&grub2_mark_regenerate_needed()
			if (&grub2_defaults_updates_need_generate(
				$old_values, $updates, \%updated));
		return ($err, %updated);
		}
	$updated{$key} = 1;
	}
return (undef, %updated);
}

# lock_bls_update_files(&old-values, &updates, &entries)
# Locks files that grubby may change so Webmin can diff them.
sub lock_bls_update_files
{
my ($old_values, $updates, $entries) = @_;
my %lock_all = &kernel_args_changed(
	$old_values->{'GRUB_CMDLINE_LINUX'}, $updates->{'GRUB_CMDLINE_LINUX'}) ?
	( all => 1 ) : ();
my %lock_default = &kernel_args_changed(
	$old_values->{'GRUB_CMDLINE_LINUX_DEFAULT'},
	$updates->{'GRUB_CMDLINE_LINUX_DEFAULT'}) ? ( default => 1 ) : ();
return () if (!%lock_all && !%lock_default);
my (@locked, %seen);
# kernelopts-based entries may be updated through grubenv instead of .conf files.
if (grep { &grub2_entry_uses_kernelopts($_) } @$entries) {
	my $file = &grub2_config_value('grubenv_file') || '';
	if ($file ne '' && -e $file && !$seen{$file}++) {
		&lock_file($file);
		push(@locked, $file);
		}
	}
foreach my $entry (@$entries) {
	next if (($entry->{'source'} || '') ne 'bls');
	# Default-only changes skip rescue entries, matching the edit form wording.
	next if (!%lock_all && &grub2_entry_is_bls_rescue($entry));
	my $file = $entry->{'file'};
	next if (!defined($file) || $file eq '' || $seen{$file}++);
	&lock_file($file);
	push(@locked, $file);
	}
return @locked;
}

# unlock_bls_update_files(files...)
# Unlocks files after grubby has run.
sub unlock_bls_update_files
{
foreach my $file (reverse @_) {
	&unlock_file($file);
	}
}

# kernel_args_changed(old-args, new-args)
# Returns true when a kernel-args delta would be applied.
sub kernel_args_changed
{
my ($old_args, $new_args) = @_;
my ($remove, $add) = &grub2_kernel_args_delta($old_args, $new_args);
return @$remove || @$add;
}
