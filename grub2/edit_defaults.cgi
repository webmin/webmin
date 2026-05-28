#!/usr/local/bin/perl
# Show a form for editing common GRUB 2 defaults.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%text);

&ReadParse();
&error_setup($text{'defaults_err'});
my %access = &get_module_acl();
&error("$text{'eacl_np'} $text{'eacl_pedit'}") if (!$access{'edit'});

my $parsed = &read_grub_defaults();
my $values = $parsed->{'values'};
my @entries = &grub2_boot_entries();

&ui_print_header(undef, $text{'defaults_title'}, "");

# BLS warnings explain when edits also need grubby or existing entry updates.
foreach my $warning (&grub2_bls_kernel_option_warnings(\@entries)) {
	print &ui_alert($warning, 'warning');
	}

print &ui_form_start("save_defaults.cgi", "post");
print &ui_table_start($text{'defaults_header'}, "width=100%", 2);
print &ui_table_row(
	&hlink($text{'defaults_default'}, "default"),
	&default_entry_input(&field_value($values->{'GRUB_DEFAULT'}, "0"),
			     \@entries),
2, undef, undef, 1);
print &ui_table_hr();
print &ui_table_row(
	&hlink($text{'defaults_timeout_style'}, "timeout_style"),
	&ui_select("timeout_style", &field_value($values->{'GRUB_TIMEOUT_STYLE'}),
		[
			[ "", $text{'defaults_keep'} ],
			[ "menu", $text{'defaults_menu'} ],
			[ "hidden", $text{'defaults_hidden'} ],
			[ "countdown", $text{'defaults_countdown'} ],
		])
);
print &ui_table_row(
	&hlink($text{'defaults_timeout'}, "timeout"),
	&ui_textbox("timeout", &field_value($values->{'GRUB_TIMEOUT'}), 8)
);
print &ui_table_row(
	&hlink($text{'defaults_kernelopts_source'}, "kernelopts_source"),
	&html_escape(&grub2_kernel_options_source_text(\@entries))
);
# Recovery is special on BLS systems because rescue entries are separate files.
print &ui_table_row(
	&hlink($text{'defaults_disable_recovery'}, "disable_recovery"),
	&bool_select("disable_recovery", $values->{'GRUB_DISABLE_RECOVERY'}).
	(&grub2_has_bls_rescue_entries() ?
		&ui_tag('div', &ui_note($text{'defaults_disable_recovery_bls'}, 0)) :
		"")
);
print &ui_table_row(
	&hlink($text{'defaults_disable_os_prober'}, "disable_os_prober"),
	&bool_select("disable_os_prober", $values->{'GRUB_DISABLE_OS_PROBER'})
);
print &ui_table_hr();
print &ui_table_row(
	&hlink($text{'defaults_cmdline_default'}, "cmdline_default"),
	&ui_textbox("cmdline_default",
		    &field_value($values->{'GRUB_CMDLINE_LINUX_DEFAULT'}), 30,
		    undef, undef, undef, "w-100")
);
print &ui_table_row(
	&hlink($text{'defaults_cmdline'}, "cmdline"),
	&ui_textbox("cmdline", &field_value($values->{'GRUB_CMDLINE_LINUX'}), 70,
		    undef, undef, undef, "w-100")
);
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("index.cgi", $text{'index_return'});

# default_entry_input(value, &entries)
# Returns a selector for known boot entries.
sub default_entry_input
{
my ($value, $entries) = @_;
my ($select_value, $options) = &default_entry_options($value, $entries);
return &ui_select("default", $select_value, $options, undef, undef, undef,
		  undef, 'style="field-sizing: content; max-width: 100%;"');
}

# default_entry_options(value, &entries)
# Returns select value and options for the default entry field.
sub default_entry_options
{
my ($current, $entries) = @_;
$current = '0' if (!defined($current) || $current eq '');
my @options;
my %seen;
my $add = sub {
	my ($value, $label) = @_;
	# Avoid duplicate selectors when GRUB_DEFAULT already names an entry.
	return if (!defined($value) || $value eq '' || $seen{$value}++);
	push(@options, [ $value, $label ]);
	};
$add->('saved', $text{'defaults_default_saved'});
if ($current =~ /^\d+\z/ && $entries->[$current]) {
	# Keep numeric defaults meaningful by showing the currently indexed entry.
	$add->($current, &text('defaults_default_current_entry', $current,
			       &default_entry_label($entries->[$current])));
	}
foreach my $entry (@$entries) {
	my $selector = &grub2_entry_selector($entry);
	next if (!defined($selector) || $selector eq '');
	$add->($selector, &default_entry_label($entry));
	}
if ($current ne '' && !$seen{$current}) {
	# Preserve unusual existing values without allowing arbitrary new input.
	$add->($current, &text('defaults_default_current', $current));
	}
my $select_value = $seen{$current} ? $current : $options[0]->[0];
return ($select_value, \@options);
}

# default_entry_label(&entry)
# Returns a concise label for one parsed generated boot entry.
sub default_entry_label
{
my ($entry) = @_;
my @path = @{$entry->{'path'} || []};
my $label = join(' > ', (@path, $entry->{'title'} || ''));
return &text('defaults_default_entry_id', $label, $entry->{'id'})
	if (defined($entry->{'id'}) && $entry->{'id'} ne '');
return $label;
}

# bool_select(name, value)
# Returns a tri-state selector for GRUB true/false settings.
sub bool_select
{
my ($name, $value) = @_;
$value = '' if (!defined($value) || $value !~ /^(true|false)\z/);
return &ui_select($name, $value,
	[
		[ "", $text{'defaults_keep'} ],
		[ "true", $text{'defaults_true'} ],
		[ "false", $text{'defaults_false'} ],
	]);
}

# field_value(value, [default])
# Returns a form value without treating the string 0 as empty.
sub field_value
{
my ($value, $default) = @_;
return defined($value) ? $value : ($default || '');
}
