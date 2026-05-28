#!/usr/local/bin/perl
# Display GRUB 2 configuration and runtime status.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%text, %access);

&error_setup($text{'acl_ecannot'});
%access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pview'}") if (!$access{'view'});
&ui_print_header(undef, $text{'status_title'}, "");

# Missing-install output mirrors index.cgi but keeps this page read-only.
if (!&grub2_any_installed()) {
	print &ui_alert($text{'index_missing'}, 'warning');
	foreach my $issue (&grub2_install_issues()) {
		print &ui_div(&text('index_missing_detail',
				    &ui_tag('tt', &html_escape($issue))));
		}
	&ui_print_footer("index.cgi", $text{'index_return'});
	exit;
	}

foreach my $warning (&grub2_status_warnings()) {
	print &ui_alert($warning, 'warning');
	}

print &ui_div($text{'index_status_desc'});

# The summary uses defaults plus grubenv because GRUB stores both persistently.
my $parsed = &read_grub_defaults();
my %env = &grub2_read_env();

&print_summary($parsed);
&print_boot_selection($parsed, \%env);
&print_security_status();
&print_theme_status($parsed);

&ui_print_footer("index.cgi", $text{'index_return'});

# print_summary(&parsed-defaults)
# Outputs a compact summary of important GRUB paths, commands, and defaults.
sub print_summary
{
my ($parsed) = @_;
my $values = $parsed->{'values'};
my @entries = &grub2_boot_entries();
print &ui_table_start($text{'index_summary'}, "width=100%", 2);
# Start with path and command discovery so support issues are visible first.
print &status_table_row($text{'index_boot_mode'}, "boot_mode",
			&boot_mode_cell());
print &status_table_row($text{'index_secure_boot'}, "secure_boot",
			&secure_boot_cell());
print &status_table_row($text{'index_default_file'}, "default_file",
			&path_cell(&grub2_config_value('default_file')));
print &status_table_row($text{'index_grub_cfg'}, "grub_cfg",
			&path_cell(&grub2_config_value('grub_cfg')));
print &status_table_row($text{'index_grub_dir'}, "grub_dir",
			&path_cell(&grub2_config_value('grub_dir')));
print &status_table_row($text{'index_bls_dir'}, "bls_dir",
			&path_cell(&grub2_config_value('bls_dir')));
print &status_table_row($text{'index_mkconfig'}, "mkconfig",
			&command_cell('mkconfig_cmd'));
print &status_table_row($text{'index_install_cmd'}, "install_cmd",
			&command_cell('install_cmd'));
print &ui_table_hr();
# Defaults below the separator mirror the editable defaults page.
print &status_table_row($text{'index_entries'}, "entries",
			&text('index_entry_count', scalar(@entries)));
print &status_table_row($text{'index_kernel_options_source'},
			"kernelopts_source",
			&value_cell(&grub2_kernel_options_source_text(\@entries)));
foreach my $pair (
	[ 'GRUB_TIMEOUT_STYLE', $text{'defaults_timeout_style'}, "timeout_style" ],
	[ 'GRUB_TIMEOUT', $text{'defaults_timeout'}, "timeout" ],
	[ 'GRUB_CMDLINE_LINUX_DEFAULT', $text{'defaults_cmdline_default'},
	  "cmdline_default" ],
	[ 'GRUB_CMDLINE_LINUX', $text{'defaults_cmdline'}, "cmdline" ],
	[ 'GRUB_DISABLE_RECOVERY', $text{'defaults_disable_recovery'},
	  "disable_recovery" ],
	[ 'GRUB_DISABLE_OS_PROBER', $text{'defaults_disable_os_prober'},
	  "disable_os_prober" ],
    )
{
	my ($key, $label, $help) = @$pair;
	print &status_table_row($label, $help, &literal_cell($values->{$key}));
	}
print &ui_table_end();
}

# print_theme_status(&parsed-defaults)
# Outputs theme and graphical menu appearance settings.
sub print_theme_status
{
my ($parsed) = @_;
my $values = $parsed->{'values'};
print &ui_hidden_table_start($text{'defaults_theme_header'}, "width=100%", 2,
			     "theme", 0);
foreach my $pair (
	[ 'GRUB_TERMINAL_OUTPUT', $text{'defaults_terminal_output'},
	  "terminal_output" ],
	[ 'GRUB_GFXMODE', $text{'defaults_gfxmode'}, "gfxmode" ],
	[ 'GRUB_THEME', $text{'defaults_theme'}, "theme" ],
	[ 'GRUB_BACKGROUND', $text{'defaults_background'}, "background" ],
	[ 'GRUB_COLOR_NORMAL', $text{'defaults_color_normal'}, "color_normal" ],
	[ 'GRUB_COLOR_HIGHLIGHT', $text{'defaults_color_highlight'},
	  "color_highlight" ],
    )
{
	my ($key, $label, $help) = @$pair;
	print &status_table_row($label, $help, &literal_cell($values->{$key}));
	}
print &ui_hidden_table_end("theme");
}

# print_boot_selection(&parsed-defaults, &env)
# Outputs saved and one-time boot selection state.
sub print_boot_selection
{
my ($parsed, $env) = @_;
print &ui_hidden_table_start($text{'index_boot_selection'}, "width=100%", 2,
			     "boot_selection", 0);
print &status_table_row($text{'defaults_default'}, "default",
			&literal_cell($parsed->{'values'}->{'GRUB_DEFAULT'}));
print &status_table_row($text{'index_saved_entry'}, "saved_entry",
			&literal_cell($env->{'saved_entry'}));
print &status_table_row($text{'index_next_entry'}, "next_entry",
			&literal_cell($env->{'next_entry'}));
print &status_table_row($text{'index_env'}, "grubenv",
			&path_cell(&grub2_config_value('grubenv_file')));
print &ui_hidden_table_end("boot_selection");
}

# print_security_status()
# Outputs Webmin-managed GRUB password protection state.
sub print_security_status
{
my $state = &grub2_read_security_config();
print &ui_alert($text{'security_unmanaged'}, 'warning')
	if ($state->{'exists'} && !$state->{'managed'});
print &ui_hidden_table_start($text{'security_header'}, "width=100%", 2,
			     "security", 0);
# Password hash contents are never displayed, only whether one is configured.
print &status_table_row($text{'index_security_state'}, "security_current",
			&security_state_cell($state));
print &status_table_row($text{'index_security_user'}, "security_user",
			$state->{'enabled'} ? &html_escape($state->{'user'}) :
					      $text{'index_not_set'});
print &status_table_row($text{'index_security_hash'}, "security_hash",
			$state->{'hash'} ? $text{'index_security_hash_set'} :
					    $text{'index_security_hash_missing'});
print &status_table_row($text{'index_security_file'}, "security_file",
			&path_cell($state->{'file'}));
print &status_table_row($text{'index_security_mkpasswd'}, "security_mkpasswd",
			&command_cell('mkpasswd_cmd'));
print &ui_hidden_table_end("security");
}

# status_table_row(label, help, value)
# Returns a standard status table row with contextual help on the label.
sub status_table_row
{
my ($label, $help, $value) = @_;
return &ui_table_row(&hlink($label, $help), $value);
}

# path_cell(path)
# Returns escaped path display HTML with missing-state text.
sub path_cell
{
my ($path) = @_;
return $text{'index_not_set'} if (!defined($path) || $path eq '');
my $html = &manual_path_link($path, &ui_tag('tt', &html_escape($path)));
return -e $path ? $html : $html.' '.$text{'index_missing_file'};
}

# command_cell(config-key)
# Returns escaped command display HTML with availability state.
sub command_cell
{
my ($key) = @_;
my $cmd = &grub2_command($key);
return &ui_tag('tt', &html_escape($cmd)) if ($cmd);
my $raw = &grub2_config_value($key);
return $text{'index_not_set'} if (!defined($raw) || $raw eq '');
return &ui_tag('tt', &html_escape($raw)).' '.$text{'index_not_readable'};
}

# manual_path_link(path, html)
# Links editable GRUB files to the manual editor when permitted.
sub manual_path_link
{
my ($path, $html) = @_;
return $html if (!$access{'manual'} || !&grub2_manual_file($path));
# Link only allowlisted paths; generated grub.cfg remains informational.
return &ui_tag('a', $html, {
	'href' => "edit_manual.cgi?file=".&urlize($path),
	});
}

# security_state_cell(&state)
# Returns text for the password protection status.
sub security_state_cell
{
my ($state) = @_;
return $text{'index_security_unmanaged'}
	if ($state->{'exists'} && !$state->{'managed'});
return $state->{'enabled'} ? $text{'index_security_enabled'} :
			     $text{'index_security_disabled'};
}

# boot_mode_cell()
# Returns the detected firmware boot mode for display.
sub boot_mode_cell
{
my $mode = &grub2_boot_mode();
return $text{'index_boot_mode_uefi'} if ($mode eq 'uefi');
return $text{'index_boot_mode_bios'};
}

# secure_boot_cell()
# Returns the detected Secure Boot state for display.
sub secure_boot_cell
{
my $state = &grub2_secure_boot_status();
return $text{'index_secure_boot_'.$state} || $text{'index_secure_boot_unknown'};
}

# value_cell(value)
# Returns escaped value display HTML with unset-state text.
sub value_cell
{
my ($value) = @_;
return $text{'index_not_set'} if (!defined($value) || $value eq '');
return $text{'defaults_true'} if ($value eq 'true');
return $text{'defaults_false'} if ($value eq 'false');
return &html_escape($value);
}

# literal_cell(value)
# Returns an escaped literal GRUB value with unset and boolean mapping.
sub literal_cell
{
my ($value) = @_;
return $text{'index_not_set'} if (!defined($value) || $value eq '');
return $text{'defaults_true'} if ($value eq 'true');
return $text{'defaults_false'} if ($value eq 'false');
return &ui_tag('tt', &html_escape($value));
}
