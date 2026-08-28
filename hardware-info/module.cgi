#!/usr/local/bin/perl
# Display details about one loaded kernel module associated with a device.

use strict;
use warnings;

require './hardware-info-lib.pl'; ## no critic

our (%in, %text);

ReadParse();
error_setup($text{'module_error'});

my $name = defined($in{'name'}) ? $in{'name'} : "";
my $module = hardware_kernel_module($name);
error($text{'module_enotfound'}) if (!$module);

ui_print_header(undef, text('module_title', html_escape($module->{'name'})),
	"", undef, 0, 1);

print ui_table_start($text{'module_details'}, "width=100%", 2,
	[ "width=30%", undef ]);
my @fields = qw(state refcount version srcversion taint);
foreach my $field (@fields) {
	next if (!defined($module->{$field}) || $module->{$field} eq "");
	print ui_table_row($text{"module_$field"},
		html_escape($module->{$field}));
	}
print ui_table_row($text{'module_coresize'}, nice_size($module->{'coresize'}))
	if (defined($module->{'coresize'}) && $module->{'coresize'} =~ /^\d+$/);
print ui_table_row($text{'module_initsize'}, nice_size($module->{'initsize'}))
	if (defined($module->{'initsize'}) && $module->{'initsize'} =~ /^\d+$/);
print ui_table_row($text{'module_holders'},
	join(", ", map { ui_tag('tt', html_escape($_)) }
		@{$module->{'holders'}})) if (@{$module->{'holders'}});
print ui_table_end();

# Keep all supplementary metadata and parameters in one expanded panel.
my $has_modinfo = $module->{'modinfo'} && keys(%{$module->{'modinfo'}});
my $has_parameters = keys(%{$module->{'parameters'}});
if ($has_modinfo || $has_parameters) {
	print ui_hidden_table_start($text{'module_additional'}, "width=100%", 2,
		"module_additional", 1, [ "width=30%", undef ]);
	foreach my $key (sort keys(%{$module->{'modinfo'} || { }})) {
		print ui_table_row(ui_tag('tt', html_escape($key)),
			html_escape($module->{'modinfo'}->{$key}));
		}
	foreach my $key (sort keys(%{$module->{'parameters'}})) {
		my $label = text('module_parameter',
			ui_tag('tt', html_escape($key)));
		print ui_table_row($label,
			ui_tag('tt', html_escape($module->{'parameters'}->{$key})));
		}
	print ui_hidden_table_end();
	}

ui_print_footer("index.cgi", $text{'view_return'});
