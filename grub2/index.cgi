#!/usr/local/bin/perl
# Display GRUB 2 boot menu and configuration status.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);
our $module_name;
our $grub2_formno = 0;

&ReadParse();
&error_setup($text{'acl_ecannot'});
my %access = &grub2_effective_acl();
&error("$text{'eacl_np'} $text{'eacl_pview'}")
	if (!&can_use_index(\%access));

# Show configuration/install guidance before rendering module actions.
if (!&grub2_any_installed()) {
	&ui_print_header(&grub2_version_text() || "", $text{'index_title'},
			 "", undef, 1, 1);
	print &ui_alert($text{'index_missing'}, 'warning');
	if ($access{'view'}) {
		# Install issue details include discovered paths and commands.
		foreach my $issue (&grub2_install_issues()) {
			print &ui_div(&text('index_missing_detail',
					    &ui_tag('tt', &html_escape($issue))));
			}
		}
	print &ui_p(&ui_link("@{[&get_webprefix()]}/config.cgi?$module_name",
			     $text{'index_config_link'}));
	if ($access{'install'} && &foreign_available("software")) {
		# Offer package installation only to users allowed to install GRUB.
		&foreign_require("software", "software-lib.pl");
		my $lnk = &software::missing_install_link(
			"grub2-common", $text{'index_install_pkg'},
			"../$module_name/", $text{'index_title'});
		print &ui_p($lnk) if ($lnk);
		}
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

&ui_print_header(&grub2_version_text() || "", $text{'index_title'}, "",
		 undef, 1, 1, undef, &grub2_action_links(\%access));

if ($access{'view'}) {
	foreach my $warning (&grub2_status_warnings()) {
		print &ui_alert($warning, 'warning');
		}

	# Only the two entry lists are tabs; global settings live in separate pages.
	my @tabs = (
		[ 'entries', $text{'index_entries_tab'} ],
		[ 'custom', $text{'index_custom_tab'} ],
	);
	my %valid = map { $_->[0] => 1 } @tabs;
	my $requested = defined($in{'mode'}) ? $in{'mode'} : '';
	my $mode = $requested && $valid{$requested} ? $requested : 'entries';
	print &ui_tabs_start(\@tabs, "mode", $mode, 1);

	print &ui_tabs_start_tab("mode", "entries");
	&print_entries_tab(\%access);
	print &ui_tabs_end_tab("mode", "entries");

	print &ui_tabs_start_tab("mode", "custom");
	&print_custom_tab(\%access);
	print &ui_tabs_end_tab("mode", "custom");

	print &ui_tabs_end();
	}

&print_action_buttons(\%access);
&ui_print_footer("/", $text{'index_return'});

# can_use_index(&access)
# Returns true if the index can show entry data or a global action.
sub can_use_index
{
my ($access) = @_;
return 1 if ($access->{'view'});
return 1 if ($access->{'edit'} || $access->{'security'} ||
	     $access->{'manual'} || $access->{'install'});
return 1 if ($access->{'apply'} && &grub2_command('mkconfig_cmd'));
return 0;
}

# print_entries_tab(&access)
# Outputs generated boot menu entries and selected-entry runtime actions.
sub print_entries_tab
{
my ($access) = @_;
my @entries = &grub2_boot_entries();
my $parsed = &read_grub_defaults();
my %env = &grub2_read_env();
# Selection roles are derived from both defaults and grubenv state.
my %selection = &grub2_entry_selection_roles(\@entries, $parsed, \%env);
my $can_default = $access->{'view'} && $access->{'runtime'} &&
		  &grub2_command('set_default_cmd');
my $can_once = $access->{'view'} && $access->{'runtime'} &&
	       &grub2_command('reboot_once_cmd');
my $show_actions = $can_default || $can_once;
print &ui_div($text{'index_entries_desc'});
if (!@entries) {
	print &ui_alert($text{'index_no_entries'}, 'info');
	return;
	}
my @heads = (
	$text{'index_col_title'},
	$text{'index_col_group'},
	$text{'index_col_selection'},
	($show_actions ? ( $text{'index_col_actions'} ) : ( )),
);
my @tds = (
	"",
	"",
	"width=10% nowrap",
	($show_actions ? ( "width=10% nowrap" ) : ( )),
);
print &ui_columns_start(\@heads, 100, 0, \@tds);
foreach my $entry (@entries) {
	# Path displays submenu nesting; BLS top-level entries have no submenu path.
	my @cols = (
		&entry_title_cell($entry),
		@{$entry->{'path'} || []}
			? &html_escape(join(' > ', @{$entry->{'path'}}))
			: $text{'index_top'},
		&selection_cell($selection{$entry->{'index'}}),
		($show_actions ? ( &entry_actions_cell(
			$entry, $can_default, $can_once) ) : ( )),
	);
	print &ui_columns_row(\@cols, \@tds);
	}
print &ui_columns_end();
}

# print_custom_tab(&access)
# Outputs editable custom menu entries from the configured custom file.
sub print_custom_tab
{
my ($access) = @_;
my $file = &grub2_config_value('custom_file') || '';
my @entries = &grub2_custom_entries($file);
my $can_edit = $access->{'manual'} && $file ne '';
print &ui_div($text{'index_custom_desc'});
if ($file eq '') {
	# A blank custom file path means the module cannot safely offer editing.
	print &ui_alert($text{'custom_enofile'}, 'info');
	return;
	}
if ($can_edit && @entries) {
	# Checked-table actions need a stable form number for select-all links.
	my $formno = $grub2_formno;
	print &ui_form_start("custom_action.cgi", "post", undef,
			     "id='grub2_custom_form'");
	$grub2_formno++;
	&print_custom_links($can_edit, scalar(@entries), $formno);
	}
elsif (@entries) {
	&print_custom_links($can_edit, scalar(@entries), $grub2_formno);
	}
if (!@entries) {
	print &ui_br();
	print &ui_p($text{'custom_empty'});
	if ($can_edit) {
		# Empty state uses a compact link, matching other Webmin list pages.
		print &ui_link("edit_custom.cgi", $text{'custom_add'},
				    "plus");
		print &ui_br();
		}
	return;
	}
# A single editable entry can be deleted, but cannot be reordered.
my $show_order = $can_edit && @entries > 1;
my @tds = $can_edit ? (
	"width=5",
	"",
	"",
	($show_order ? ( "width=40 style='white-space: nowrap; text-align: center'" ) : ( )),
	) : ( );
print &ui_columns_start([
	($can_edit ? ( "" ) : ( )),
	$text{'index_col_title'},
	$text{'index_col_group'},
	($show_order ? ( $text{'index_col_order'} ) : ( )),
	], 100, 0, \@tds);
foreach my $entry (@entries) {
	# Custom indexes refer to parsed menuentry blocks in the custom file.
	my $idx = $entry->{'custom_index'};
	my $title = &entry_title_cell($entry, "edit_custom.cgi?idx=$idx");
	my @cols = (
		$title,
		@{$entry->{'path'} || []}
			? &html_escape(join(' > ', @{$entry->{'path'}}))
			: $text{'index_top'},
		($show_order ? ( &custom_order_cell($idx, \@entries) ) : ( )),
	);
	if ($can_edit) {
		print &ui_checked_columns_row(\@cols, \@tds, "d", $idx);
		}
	else {
		print &ui_columns_row(\@cols);
		}
	}
print &ui_columns_end();
if ($can_edit) {
	my @left_buttons;
	my @right_buttons = (
		[ "delete", $text{'index_delete_entry'}, undef, undef,
		  "form='grub2_custom_form'" ],
	);
	print &ui_form_end_side_by_side("grub2_custom_form",
					\@left_buttons, \@right_buttons);
	}
}

# print_action_buttons(&access)
# Outputs the main module actions allowed by ACLs.
sub print_action_buttons
{
my ($access) = @_;
my (@links, @titles, @icons);
my $can_status = $access->{'view'};
my $can_generate = $access->{'apply'} && &grub2_command('mkconfig_cmd');
if ($access->{'install'}) {
	# Primary action tiles are ACL-filtered so unavailable pages stay hidden.
	push(@links, "edit_install.cgi");
	push(@titles, $text{'index_install'});
	push(@icons, "images/install.svg");
	}
if ($access->{'edit'}) {
	push(@links, "edit_defaults.cgi");
	push(@titles, $text{'index_edit_defaults'});
	push(@icons, "images/defaults.svg");
	}
if ($access->{'security'}) {
	push(@links, "edit_security.cgi");
	push(@titles, $text{'index_edit_security'});
	push(@icons, "images/security.svg");
	}
if ($access->{'edit'}) {
	push(@links, "edit_theme.cgi");
	push(@titles, $text{'index_edit_theme'});
	push(@icons, "images/theme.svg");
	}
if ($access->{'manual'}) {
	push(@links, "edit_manual.cgi");
	push(@titles, $text{'index_manual'});
	push(@icons, "images/manual.svg");
	}
return if (!@links && !$can_status && !$can_generate);
# Without view content, the action hub should start directly with actions.
print &ui_hr() if ($access->{'view'});
if (@links) {
	print &ui_subheading($text{'index_global'});
	&icons_table(\@links, \@titles, \@icons, scalar(@links) > 5 ? 5 :
		     scalar(@links));
	}
if ($can_status || $can_generate) {
	print &ui_hr() if (@links);
	print &ui_buttons_start();
	print &ui_buttons_row("status.cgi", $text{'index_view_status'},
			      $text{'index_view_status_msg'}, undef, undef,
			      undef, "get") if ($can_status);
	print &ui_buttons_row("generate.cgi", $text{'index_generate'},
			      $text{'index_generate_msg'},
			      [ [ "redir", &grub2_this_url() ] ])
		if ($can_generate);
	print &ui_buttons_end();
	}
}

# print_custom_links(can-edit?, entry-count, form-number)
# Outputs checked-table links for custom entries.
sub print_custom_links
{
my ($can_edit, $count, $formno) = @_;
return if (!$can_edit);
my @left;
if ($count) {
	push(@left, &select_all_link("d", $formno),
	     &select_invert_link("d", $formno));
	}
push(@left, &ui_link("edit_custom.cgi", $text{'custom_add'}));
print &ui_links_row(\@left);
}

# selection_cell(&roles)
# Returns display text for default and next-boot entry roles.
sub selection_cell
{
my ($roles) = @_;
return '' if (!$roles || !@$roles);
my @labels = map { $text{'index_selection_'.$_} || $_ } @$roles;
return join(', ', @labels);
}

# entry_title_cell(&entry, [link])
# Returns a title cell with useful GRUB entry metadata in inline details.
sub entry_title_cell
{
my ($entry, $link) = @_;
my $title = &html_escape($entry->{'title'} || '');
my $summary = $link ?
	&ui_tag('a', $title, { href => $link, style => 'padding: 0;' }) :
	$title;
return &ui_details({
	'html' => 1,
	'title' => $summary,
	'content' => &entry_details_content($entry),
	'class' => 'inline inlined',
	});
}

# entry_details_content(&entry)
# Returns compact metadata for a boot entry details disclosure.
sub entry_details_content
{
my ($entry) = @_;
my @rows;
my $index = defined($entry->{'index'}) ? $entry->{'index'} :
	    $entry->{'custom_index'};
# Only include rows that help identify or troubleshoot the selected entry.
push(@rows, &entry_detail_line($text{'index_col_index'}, $index))
	if (defined($index));
push(@rows, &entry_detail_line($text{'index_col_id'}, $entry->{'id'}))
	if ($entry->{'id'});
push(@rows, &entry_source_detail_line($entry))
	if ($entry->{'source_file'});
push(@rows, &entry_detail_line($text{'index_col_version'},
			       $entry->{'version'}));
push(@rows, &entry_detail_line($text{'index_col_kernel'},
			       $entry->{'linux'}));
push(@rows, &entry_detail_line($text{'index_col_initrd'},
			       $entry->{'initrd'}));
push(@rows, &entry_detail_line($text{'index_col_machine_id'},
			       $entry->{'machine-id'}));
push(@rows, &entry_detail_line($text{'index_col_options'},
			       $entry->{'options'}));
return join('', @rows);
}

# entry_source_detail_line(&entry)
# Returns source details without implying generator scripts are entry files.
sub entry_source_detail_line
{
my ($entry) = @_;
my $file = $entry->{'source_file'} || '';
return '' if (!defined($file) || $file eq '');
my $custom_file = &grub2_config_value('custom_file') || '';
my $direct_file = (($entry->{'source'} || '') eq 'bls') ||
		  ($custom_file ne '' && $file eq $custom_file);
# Direct entry files are shortened for readability; generator scripts are not.
my $label = $direct_file ? $text{'index_col_file'} :
	    $text{'index_col_generator'};
my $html;
if ($direct_file) {
	my $display = &entry_file_display_name($file);
	$html = &ui_tag('tt', &html_escape($display), { 'title' => $file });
	}
else {
	$html = &ui_tag('tt', &html_escape($file));
	}
if (&grub2_check_acl('manual') && &grub2_manual_file($file)) {
	# The manual editor repeats its allowlist check on entry.
	$html = &ui_tag('a', $html, {
		'href' => "edit_manual.cgi?file=".&urlize($file),
		});
	}
return &entry_detail_line($label, $html, 1);
}

# entry_file_display_name(file)
# Returns a short display name for a linked entry file.
sub entry_file_display_name
{
my ($file) = @_;
$file = '' if (!defined($file));
$file =~ s{.*/}{};
return $file;
}

# entry_detail_line(label, value, [html-value?])
# Returns one escaped metadata line for a boot entry details disclosure.
sub entry_detail_line
{
my ($label, $value, $html) = @_;
return '' if (!defined($value) || $value eq '');
my $display = $html ? $value : &ui_tag('tt', &html_escape($value));
return &ui_tag('div',
	       &ui_tag('span', &html_escape($label).':',
		       { 'style' => 'white-space: nowrap;' }).
	       &ui_tag('span', $display,
		       { 'style' => 'min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere;' }),
	       { 'style' => 'display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 0.35em; align-items: start;' });
}

# entry_actions_cell(&entry, can-default?, can-once?)
# Returns runtime action links for one generated boot entry.
sub entry_actions_cell
{
my ($entry, $can_default, $can_once) = @_;
my $idx = $entry->{'index'};
my @actions;
push(@actions, &ui_link("set_default.cgi?idx=$idx",
			$text{'index_set_default'})) if ($can_default);
push(@actions, &ui_link("reboot_once.cgi?idx=$idx",
			$text{'index_reboot_once'})) if ($can_once);
return join(' | ', @actions);
}

# custom_order_cell(index, &entries)
# Returns up/down ordering controls for one custom entry row.
sub custom_order_cell
{
my ($idx, $entries) = @_;
my $up = $idx > 0 &&
	&grub2_paths_equal($entries->[$idx], $entries->[$idx - 1]);
my $down = $idx < @$entries - 1 &&
	&grub2_paths_equal($entries->[$idx], $entries->[$idx + 1]);
# Disable movement across submenu boundaries so nesting remains intact.
return &ui_up_down_arrows("custom_action.cgi?idx=$idx&dir=up",
			  "custom_action.cgi?idx=$idx&dir=down",
			  $up, $down);
}
