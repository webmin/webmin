#!/usr/bin/perl
# Tests for the widget functions added to ui-lib.pl and their escaping
# contract.
#
# These cover the default (non-theme) code path. The widgets' contract is
# that text-valued options are escaped by the library itself, so an
# attribute-breakout or element-breakout payload passed as plain text
# must never survive into markup.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $root = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..'));
require File::Spec->catfile($root, 'web-lib-funcs.pl');
require File::Spec->catfile($root, 'ui-lib.pl');

# Resolve the asset versions from this checkout, without init_config
our $root_directory = $root;

# Suppress the asset tags, whose legitimate <script src> would trip the
# injection scanner below
$main::ui_page_assets_done = 1;

# Strip all quoted attribute values so that anything that broke out of an
# attribute shows up in the remaining scaffolding.
sub strip_attr_values {
	my ($html) = @_;
	$html =~ s/"[^"]*"//g;
	$html =~ s/'[^']*'//g;
	return $html;
}

sub assert_no_handler_injection {
	my ($html, $label) = @_;
	my $bare = strip_attr_values($html);
	unlike($bare, qr/\bon[a-z]+\s*=/i,
		"$label: no event-handler attribute leaks out");
	unlike($bare, qr/<script/i, "$label: no script element leaks out");
}

my $xss = q{x"><script>alert(1)</script><b onmouseover="alert(1)};

# ---- escaping contract -----------------------------------------------------

assert_no_handler_injection(
	main::ui_page_start({ 'title' => $xss, 'desc' => $xss,
			      'help' => $xss, 'help_title' => $xss }),
	'ui_page_start');
assert_no_handler_injection(
	main::ui_card({ 'title' => $xss, 'desc' => $xss }),
	'ui_card title+desc');
assert_no_handler_injection(main::ui_badge($xss, 'success'),
	'ui_badge text');
assert_no_handler_injection(main::ui_chip($xss), 'ui_chip text');
assert_no_handler_injection(main::ui_code($xss), 'ui_code');
assert_no_handler_injection(main::ui_tip('<b>x</b>', $xss), 'ui_tip');
my $tip = main::ui_tip('<b>x</b>', 'A <i>tip</i>');
like($tip, qr/^<span (?=[^>]*\bclass="ui--span ui_tip")(?=[^>]*\baria-label="A tip")(?=[^>]*\bdata-tooltip[\s>])[^>]*><b>x<\/b><\/span>$/,
     'ui_tip uses the theme tooltip attributes of ui_help');
unlike($tip, qr/data-ui-tip|tabindex/, 'ui_tip draws no tooltip of its own');
assert_no_handler_injection(
	main::ui_dl([ { 'label' => $xss, 'value' => $xss, 'help' => $xss } ]),
	'ui_dl hash row');
assert_no_handler_injection(
	main::ui_list([ { 'title' => $xss, 'desc' => $xss,
			  'meta' => $xss, 'tags' => [ $xss ],
			  'href' => $xss } ]),
	'ui_list item');
assert_no_handler_injection(
	main::ui_feed([ { 'when' => $xss, 'text' => $xss } ]),
	'ui_feed event');
assert_no_handler_injection(
	main::ui_stat({ 'value' => $xss, 'label' => $xss, 'href' => $xss }),
	'ui_stat');
assert_no_handler_injection(
	main::ui_empty_state({ 'title' => $xss, 'desc' => $xss }),
	'ui_empty_state');
assert_no_handler_injection(
	main::ui_toggle({ 'name' => $xss, 'label' => $xss, 'value' => $xss }),
	'ui_toggle');
assert_no_handler_injection(
	main::ui_search({ 'name' => $xss, 'value' => $xss,
			  'placeholder' => $xss, 'filter' => $xss }),
	'ui_search');
assert_no_handler_injection(
	main::ui_progress(50, { 'label' => $xss, 'value' => $xss }),
	'ui_progress');
assert_no_handler_injection(
	main::ui_grid([ '<b>a</b>' ], { 'template' => $xss, 'min' => $xss }),
	'ui_grid style options');

# ---- structural behavior ---------------------------------------------------

# States are validated and aliases mapped
like(main::ui_badge('up', 'ok'), qr/ui_badge_success/,
	'state alias ok maps to success');
like(main::ui_badge('down', 'err'), qr/ui_badge_danger/,
	'state alias err maps to danger');
like(main::ui_badge('what', 'bogus<'), qr/ui_badge_neutral/,
	'unknown state falls back to neutral');

# The scheme option stamps the wrapper for the dark or auto palette
like(main::ui_page_start({ 'scheme' => 'auto' }),
	qr/data-ui-scheme="auto"/, 'scheme auto stamps the wrapper');
like(main::ui_page_start({ 'scheme' => 'dark' }),
	qr/data-ui-scheme="dark"/, 'scheme dark stamps the wrapper');
unlike(main::ui_page_start({ 'scheme' => 'bogus"' }),
	qr/data-ui-scheme/, 'invalid scheme is dropped');

# Class names follow the ui_ convention of the rest of the library
{
	my $html = main::ui_page_start().main::ui_card({ 'title' => 'T' }).
		   main::ui_badge('B').main::ui_chip('C');
	like($html, qr/class="[^"]*\bui_page\b/, 'page wrapper uses a ui_ class');
	like($html, qr/class="ui--div /, 'markup is built with the ui_tag API');
	unlike($html, qr/nova/, 'no nova-prefixed names in generated markup');
}

# Description lists accept both array and hash rows
{
	my $html = main::ui_dl([ [ 'Label', '<b>html</b>' ],
				 { 'label' => 'Esc', 'value' => '<b>text</b>' } ]);
	like($html, qr/<dd[^>]*><b>html<\/b><\/dd>/, 'array row value is HTML');
	like($html, qr/&lt;b&gt;text&lt;\/b&gt;/, 'hash row value is escaped');
	like(main::ui_dl([ [ 'L', 'v', 'tip' ] ]), qr/ui_help/,
		'help text uses the existing ui_help bubble');
}

# Cards compose header, body and footer
{
	my $html = main::ui_card({ 'title' => 'T', 'actions' => '<i>a</i>',
				   'body' => '<p>b</p>', 'footer' => 'f',
				   'flush' => 1, 'state' => 'warn' });
	like($html, qr/ui_card_warning/, 'card state alias applied');
	like($html, qr/ui_card_actions"><i>a<\/i>/, 'card actions are raw HTML');
	like($html, qr/ui_card_flush/, 'flush option applied');
	like($html, qr/<footer class="[^"]*ui_card_foot">f<\/footer>/,
		'footer emitted');
}

# Grids skip empty cells and honor the template option
{
	my $html = main::ui_grid([ 'a', undef, '', 'b' ], { 'template' => '1fr 2fr' });
	like($html, qr/--ui-grid-template:1fr 2fr/, 'template option applied');
	is(scalar(() = $html =~ /^(a|b)$/mg), 2, 'empty cells are dropped');
}

# Toggles submit like checkboxes and default their value to 1. Attribute
# order is not fixed by ui_tag, so each one is checked on its own.
{
	my $html = main::ui_toggle({ 'name' => 'boot', 'checked' => 1,
				     'attrs' => { 'data-x' => 'y' } });
	my ($input) = $html =~ /(<input[^>]*>)/;
	like($input, qr/\btype="checkbox"/, 'toggle is a checkbox');
	like($input, qr/\bvalue="1"/, 'toggle value defaults to 1');
	like($input, qr/\bchecked\b/, 'toggle checked state emitted');
	like($input, qr/\bdata-x="y"/, 'toggle passes extra attrs to the input');
	unlike(main::ui_toggle({ 'name' => 'boot' }), qr/\bchecked\b/,
		'toggle unchecked by default');
	like(main::ui_toggle({ 'name' => 'boot', 'value' => '' }),
		qr/\bvalue=""/, 'toggle preserves an explicitly empty submitted value');
}

# Search boxes carry the client-side filter target
like(main::ui_search({ 'name' => 'q', 'filter' => '#rows' }),
	qr/data-ui-filter="#rows"/, 'search filter selector emitted');

# Progress percentages are clamped, scaled by max, and colored by thresholds
like(main::ui_progress(250), qr/width:100%/, 'progress clamps above 100');
like(main::ui_progress('junk'), qr/width:0%/, 'progress treats junk as 0');
like(main::ui_progress('1.2.3'), qr/width:0%/,
	'progress rejects malformed decimal values');
like(main::ui_progress(25, { 'max' => '1.2.3' }), qr/width:25%/,
	'progress falls back to 100 for a malformed maximum');
like(main::ui_progress(3.4, { 'max' => 10 }), qr/width:34%/,
	'progress scales the value by max');
like(main::ui_progress(45, { 'thresholds' => 1 }), qr/ui_bg_success/,
	'below the thresholds the bar is green');
like(main::ui_progress(78, { 'thresholds' => 1 }), qr/ui_bg_warning/,
	'past the first threshold the bar is orange');
like(main::ui_progress(96, { 'thresholds' => [ 60, 85 ] }), qr/ui_bg_danger/,
	'past a custom second threshold the bar is red');
like(main::ui_progress(96, { 'thresholds' => 1, 'state' => 'info' }),
	qr/ui_bg_info/, 'an explicit state wins over thresholds');

# Progress layouts and variants
{
	my $seg = main::ui_progress(0, { 'segments' => [
		{ 'pct' => 40, 'state' => 'info', 'label' => $xss },
		{ 'pct' => 30, 'state' => 'warning', 'label' => 'Cache' } ] });
	is(scalar(() = $seg =~ /ui_progress_bar/g), 2, 'segments draw one bar each');
	like($seg, qr/aria-valuenow="70"/, 'segment percentages add up');
	like($seg, qr/ui_progress_legend/, 'labelled segments get a legend');
	assert_no_handler_injection($seg, 'ui_progress segment label');

	my $busy = main::ui_progress(0, { 'indeterminate' => 1 });
	like($busy, qr/aria-busy="true"/, 'indeterminate bar is marked busy');
	unlike($busy, qr/aria-valuenow/, 'indeterminate bar has no value');
	unlike($busy, qr/width:/, 'indeterminate bar has no fixed width');

	like(main::ui_progress(50, { 'inline' => 1, 'label' => 'CPU' }),
		qr/ui_progress_inline.*ui_progress_label[^<]*<\/span>.*ui_progress_track.*ui_progress_value/s,
		'inline layout puts label, track and value in a row');
	like(main::ui_progress(62, { 'inside' => 1 }),
		qr/ui_progress_bar[^>]*><span[^>]*ui_progress_inside_value[^>]*>62%</,
		'inside option puts the value marker on the bar');
	like(main::ui_progress(97, { 'inside' => 1 }), qr/ui_progress_inside_end/,
		'inside marker is kept within the track near 100%');
	my $ring = main::ui_progress(34, { 'ring' => 1, 'size' => 72 });
	like($ring, qr/<svg[^>]*width="72"/, 'ring is an SVG of the given size');
	like($ring, qr/stroke-dasharray="34 100"/, 'ring dash length is the percentage');
	like($ring, qr/stroke-width="1\.50"/, 'ring stroke scales to 3px at 72px');
	like(main::ui_progress(34, { 'ring' => 1 }), qr/stroke-width="1\.93"/,
		'ring stroke scales to 3px at the default size');
	foreach my $size ('auto', 0.5, -1) {
		my $html = eval { main::ui_progress(34, { 'ring' => 1, 'size' => $size }) };
		is($@, '', "ring size $size does not crash rendering");
		like($html, qr/<svg[^>]*width="56"/,
			"ring size $size falls back to the default");
		}
}

# Choice lists : escaping, selection, fields and disabled options
{
	my $html = main::ui_choice('dest', 'ftp', [
		{ 'value' => 'local', 'label' => $xss, 'desc' => $xss },
		{ 'value' => 'ftp', 'label' => 'FTP', 'content' => '<i>host</i>',
		  'fields' => [ [ $xss, '<i>user</i>' ],
				{ 'label' => 'Port', 'html' => '<i>port</i>' } ] },
		{ 'value' => 'none', 'label' => 'None', 'disabled' => 1 } ]);
	assert_no_handler_injection($html, 'ui_choice');
	is(scalar(() = $html =~ /type=.radio./g), 3, 'one radio per option');
	like($html, qr/<input[^>]*value=.ftp.[^>]*\bchecked\b/,
		'the given value is checked');
	is(scalar(() = $html =~ /ui_choice_field"/g), 2, 'both field forms render');
	like($html, qr/ui_choice_content"><i>host<\/i>/, 'content is raw HTML');
	like($html, qr/<input[^>]*value=.none.[^>]*\bdisabled\b/,
		'disabled option disables its button');
	like($html, qr/role="radiogroup"/, 'radio list is a radiogroup');
	is(scalar(() = $html =~ /\bchecked\b/g), 1, 'exactly one option is checked');
	like($html, qr/class=.ui_radio./, 'buttons come from ui_oneradio');
}

# Radio lists and select switches
{
	my $list = main::ui_radio_list('mode', 'shared', [
		{ 'value' => 'none', 'label' => $xss },
		{ 'value' => 'shared', 'label' => 'Shared', 'content' => '<i>sel</i>' } ]);
	assert_no_handler_injection($list, 'ui_radio_list');
	is(scalar(() = $list =~ /type=.radio./g), 2, 'one radio per list option');
	like($list, qr/<input[^>]*value=.shared.[^>]*\bchecked\b/,
		'radio list checks the given value');
	like($list, qr/ui_radio_list_content"><i>sel<\/i>/, 'radio list content is raw HTML');

	my $sw = main::ui_select_switch('dest', 'ftp', [
		{ 'value' => 'local', 'label' => $xss, 'content' => '<i>file</i>' },
		{ 'value' => 'ftp', 'label' => 'FTP', 'desc' => $xss,
		  'fields' => [ [ $xss, '<i>host</i>' ] ] },
		{ 'value' => 'none', 'label' => 'None' } ]);
	assert_no_handler_injection($sw, 'ui_select_switch');
	like($sw, qr/<select[^>]*data-ui-switch/, 'switch select carries the hook');
	my @panels = $sw =~ /(<div[^>]*ui_select_switch_panel[^>]*>)/g;
	is(scalar(@panels), 2, 'options with nothing to show get no block');
	my ($ftp) = grep { /data-ui-switch-value="ftp"/ } @panels;
	unlike($ftp, qr/\bhidden\b/, 'the chosen block is visible');
	my ($local) = grep { /data-ui-switch-value="local"/ } @panels;
	like($local, qr/\bhidden\b/, 'other blocks are hidden');
	like($sw, qr/ui_select_switch_field_input"><i>host<\/i>/, 'switch fields are raw HTML');
	like($sw, qr/ui_select_switch_field_label">FTP<\/span>|ui_select_switch_field_label">x&quot;/,
		'inline content of a block is labelled with the option name');

	# A removed saved option must agree with the browser's first-option
	# fallback, including when the first option has an empty value.
	foreach my $first ('local', undef) {
		my $fallback = main::ui_select_switch('dest', 'removed', [
			{ 'value' => $first, 'label' => 'Default', 'content' => 'File' },
			{ 'value' => 'ftp', 'label' => 'FTP', 'content' => 'Host' } ]);
		my @panels = $fallback =~ /(<div[^>]*ui_select_switch_panel[^>]*>)/g;
		unlike($panels[0], qr/\bhidden\b/, 'fallback option panel is visible');
		like($panels[1], qr/\bhidden\b/, 'other option panel stays hidden');
		like($fallback, qr/<option value="(?:local)?" selected>/,
			'fallback option is explicitly selected');
		}
	is(main::ui_select_switch('dest', undef, undef), '',
		'no switch options produces no markup');
}

# Sortable column tables carry the data-sortable marker for themes
like(main::ui_columns_start([ 'A' ], 100, 0, undef, undef, 1),
	qr/data-sortable='1'/, 'ui_columns_start marks sortable tables');
unlike(main::ui_columns_start([ 'A' ], 100),
	qr/data-sortable/, 'ui_columns_start is plain by default');
like(main::ui_columns_table([ 'A' ], 100, [ [ 'x' ] ], undef, 0, undef, undef, 1),
	qr/data-sortable='1'/, 'ui_columns_table passes the sortable flag on');
like(main::ui_form_columns_table('x.cgi', [ [ 'go', 'Go' ] ], 0, undef, undef,
	[ 'A' ], 100, [ [ 'x' ] ], undef, 0, undef, undef, 0, 1),
	qr/data-sortable='1'/, 'ui_form_columns_table passes the sortable flag on');

# The assets are only emitted once per request
{
	local $main::ui_page_assets_done = 0;
	my $first = main::ui_page_assets();
	my $second = main::ui_page_assets();
	like($first, qr/ui-lib\.css/, 'first assets call links the stylesheet');
	like($first, qr/ui-lib\.js/, 'first assets call loads the script');
	is($second, '', 'second assets call emits nothing');
}

done_testing();
