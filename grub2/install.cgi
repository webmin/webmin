#!/usr/local/bin/perl
# Install the GRUB 2 boot loader with progress output.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'install_err'});
&grub2_assert_acl('install');

# Trim text fields before validation so shell arguments are deterministic.
foreach my $field (qw(target efi_dir platform directory boot_directory
		      bootloader_id)) {
	$in{$field} = "" if (!defined($in{$field}));
	$in{$field} =~ s/^\s+|\s+\z//g;
	}
&error($text{'install_eboot_directory_required'})
	if ($in{'use_boot_directory'} && $in{'boot_directory'} eq '');
my %opts = (
	'target' => $in{'target'},
	'efi_dir' => $in{'efi_dir'},
	'platform' => $in{'platform'} || &grub2_default_platform_target(),
	'directory' => $in{'directory'},
	'boot_directory' => $in{'use_boot_directory'} ? $in{'boot_directory'} : '',
	'bootloader_id' => $in{'bootloader_id'},
	'recheck' => $in{'recheck'} ? 1 : 0,
	'removable' => $in{'removable'} ? 1 : 0,
	'no_nvram' => $in{'no_nvram'} ? 1 : 0,
	'force' => $in{'force'} ? 1 : 0,
);
$in{'confirm'} || &error($text{'install_econfirm'});
&grub2_command('install_cmd') || &error($text{'install_ecmd'});
# Validate all paths and identifiers before any progress output is started.
my $precheck = &grub2_validate_install_options(\%opts);
&error($precheck) if ($precheck);

my ($pre_open, $current_step, $failed_printed, $captured_output) =
	(0, '', 0, '');

&ui_print_unbuffered_header(undef, $text{'install_progress_title'}, "");

my $callback = sub {
	my ($event, $value) = @_;
	if ($event eq 'command') {
		# The first event opens the visible command transcript.
		$current_step = 'command';
		&print_step_start($text{'install_installing'});
		print &ui_tag_start('pre', { 'style' => 'margin-left: 10px;' });
		$pre_open = 1;
		print &html_escape($value)."\n";
		return;
		}
	if ($event eq 'output') {
		# Some commands emit output before command_done; keep one pre open.
		if (!$pre_open) {
			print &ui_tag_start('pre',
					    { 'style' => 'margin-left: 10px;' });
			$pre_open = 1;
			}
		$captured_output .= $value;
		print &html_escape($value);
		return;
		}
	if ($event eq 'command_done') {
		# Close the transcript before printing the final status marker.
		&close_output(\$pre_open);
		&print_step_done(\$current_step);
		return;
		}
	if ($event eq 'command_failed') {
		# Print only one failure line even if the caller also returns an error.
		&close_output(\$pre_open);
		&print_step_failed(\$current_step, \$failed_printed);
		return;
		}
	};

my $err = &grub2_install_bootloader(\%opts, $callback);
&close_output(\$pre_open);
if ($err) {
	# Avoid duplicating the same error when it was already in command output.
	&print_step_failed(\$current_step, \$failed_printed)
		if ($current_step);
	my $shown = $captured_output || '';
	$shown =~ s/^\s+|\s+\z//g;
	print &ui_tag('pre', &html_escape($err),
		      { 'style' => 'margin-left: 10px;' })
		if ($err ne $shown);
	}
else {
	&webmin_log("install", undef, &grub2_install_log_target(\%opts));
	}

&ui_print_footer("index.cgi", $text{'install_return'});

# close_output(&open-flag)
# Closes the command output block when it is currently being printed.
sub close_output
{
my ($open) = @_;
if ($$open) {
	print &ui_tag_end('pre');
	$$open = 0;
	}
return;
}

# print_step_start(text)
# Prints the first progress line for the installation step.
sub print_step_start
{
my ($msg) = @_;
print &ui_tag('span', &html_escape($msg." .."),
	      { 'data-first-print' => undef });
print "<br>\n";
return;
}

# print_step_done(&current-step)
# Prints a successful progress line and clears the active step.
sub print_step_done
{
my ($current) = @_;
print &ui_tag('span', &html_escape(".. ".$text{'install_done'}),
	      { 'data-second-print' => undef });
print "<br><div data-x-br=\"\"></div>\n";
$$current = '';
return;
}

# print_step_failed(&current-step, &printed-flag)
# Prints a failed progress line once and clears the active step.
sub print_step_failed
{
my ($current, $printed) = @_;
return if ($$printed);
print &ui_tag('span', &html_escape(".. ".$text{'install_failed_status'}),
	      { 'data-second-print' => undef });
print "<br><div data-x-br=\"\"></div>\n";
$$current = '';
$$printed = 1;
return;
}
