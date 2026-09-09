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

# Load widget strings without init_config.
open(my $LANG, "<", File::Spec->catfile($root, 'lang', 'en')) or
	die "lang/en: $!";
while(my $line = <$LANG>) {
	$main::text{$1} = $2 if ($line =~ /^([A-Za-z0-9_]+)=(.*)/);
	}
close($LANG);

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

# Decode once like a browser; html_unescape also expands nested entities.
sub decode_attr {
	my ($value) = @_;
	my %entities = ( 'amp' => '&', 'lt' => '<', 'gt' => '>',
			 'quot' => '"', '#39' => "'", '#61' => '=' );
	$value =~ s/&(amp|lt|gt|quot|#39|#61);/$entities{$1}/ge;
	return $value;
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
	like($html, qr/\bui_toggle_neutral\b/,
		'toggle defaults to the secondary color');
	unlike($html, qr/\bui_toggle_outline\b/, 'toggle is filled by default');
	unlike($html, qr/\bui_toggle_round\b/, 'toggle uses the default compact shape');
}

# Toggle states share the widget aliases without changing checkbox behavior.
{
	foreach my $case ([ 'primary', 'primary' ], [ 'success', 'success' ],
			  [ 'warning', 'warning' ],
			  [ 'error', 'danger' ], [ 'info', 'info' ],
			  [ 'secondary', 'neutral' ], [ 'gray', 'neutral' ],
			  [ 'grey', 'neutral' ], [ 'invalid<', 'neutral' ]) {
		my ($state, $suffix) = @$case;
		my $html = main::ui_toggle({ 'name' => 'colored', 'state' => $state,
			'class' => 'custom' });
		like($html, qr/<label\b[^>]*class="[^"]*\bui_toggle_$suffix\b[^"]*\bcustom\b/,
			"toggle maps $state and preserves the custom class");
	}
	my $html = main::ui_toggle({ 'name' => 'colored', 'state' => 'success',
		'checked' => 1, 'disabled' => 1, 'value' => 'yes' });
	my ($input) = $html =~ /(<input[^>]*>)/;
	like($input, qr/\bchecked\b/, 'colored toggle stays checked');
	like($input, qr/\bdisabled\b/, 'colored toggle stays disabled');
	like($input, qr/\bvalue="yes"/, 'colored toggle preserves its value');
}

# Outline is optional and leaves the checkbox attributes intact.
{
	my $html = main::ui_toggle({ 'name' => 'outlined', 'state' => 'error',
		'outline' => 1, 'checked' => 1, 'disabled' => 1, 'value' => 'yes' });
	like($html, qr/\bui_toggle_danger\b[^"]*\bui_toggle_outline\b/,
		'outline combines with the normalized state');
	my ($input) = $html =~ /(<input[^>]*>)/;
	like($input, qr/\bchecked\b/, 'outline preserves checked state');
	like($input, qr/\bdisabled\b/, 'outline preserves disabled state');
	like($input, qr/\bvalue="yes"/, 'outline preserves the submitted value');
	unlike(main::ui_toggle({ 'name' => 'plain', 'outline' => 0 }),
		qr/\bui_toggle_outline\b/, 'outline can be explicitly disabled');
}

# Rounding applies independently of the toggle's color and outline style.
{
	foreach my $outline (0, 1) {
		my $html = main::ui_toggle({ 'name' => 'rounded', 'state' => 'primary',
			'round' => 1, 'outline' => $outline });
		like($html, qr/\bui_toggle_primary\b[^"]*\bui_toggle_round\b/,
			"rounding applies with outline=$outline");
	}
	unlike(main::ui_toggle({ 'name' => 'square', 'round' => 0 }),
		qr/\bui_toggle_round\b/, 'rounding can be explicitly disabled');
}

# Column tables take extra class names for the theme, such as no-hover
like(main::ui_columns_start([ 'A' ], undef, 0, undef, undef, 0, 'no-hover'),
	qr/class='ui_columns no-hover'/, 'ui_columns_start adds the class argument');
like(main::ui_columns_start([ 'A' ]), qr/class='ui_columns'/,
	'ui_columns_start without the class argument is unchanged');

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

# Multi-select values, modes, controls and hierarchy.
# Match attributes independently because their order varies.
{
	my $html = main::ui_multi_select_list('doms',
		[ 'b', [ 'zz', 'Gone' ] ],
		[ [ 'a', 'A' ],
		  { 'value' => 'b', 'label' => 'B', 'suffix' => '.x',
		    'level' => 1, 'tag' => 'Plan' },
		  [ 'c', 'C' ], map { [ $_, uc($_) ] } qw(d e f g h) ],
		{ 'modes' => { 'name' => 'all', 'value' => 1,
			       'options' => [ [ 1, 'All' ], [ 0, 'Some' ] ],
			       'hide' => [ 1 ] } });
	like($html, qr/type='hidden'[^>]*name="doms"[^>]*value="b\nzz"/,
		'hidden input carries the newline-joined selection');
	like($html, qr/name="doms_item" value="b"[^>]*checked/,
		'selected entry is checked');
	unlike($html, qr/name="doms_item" value="a"[^>]*checked/,
		'unselected entry is not checked');
	like($html, qr/value="zz"[^>]*checked/,
		'selected value missing from the options is added');
	like($html, qr/>Gone</, 'and keeps the label given with it');
	like($html, qr/ui_multi_suffix">\.x</, 'suffix follows the label');
	like($html, qr/data-ui-multi-text="B\.x Plan"/,
		'filter text keeps the label and suffix joined for full-name searches');
	like($html, qr/\bui_multi_level1\b/, 'level indents the row');
	like($html, qr/ui_chip">Plan</, 'tag is a chip');
	like($html, qr/<a (?=[^>]*\bselect_all\b)(?=[^>]*data-ui-multi-action="all")/,
		'select all is the usual link');
	like($html, qr/<a (?=[^>]*\bselect_invert\b)(?=[^>]*data-ui-multi-action="invert")/,
		'invert selection is the usual link');
	like($html, qr/select_all[^>]*>[^<]*<\/a>\s*\|\s*<a/s,
		'the links are laid out by ui_links_row');
	unlike($html, qr/<br>\s*<span[^>]*ui_search/,
		'without the line break that row ends with');
	unlike(main::ui_multi_select_list('x', [ ], [ map { [ $_, $_ ] } 1..9 ], { 'disabled' => 1 }),
		qr/select_all/, 'a disabled widget has no links');
	like($html, qr/<select [^>]*name="all"/, 'modes are a select by default');
	my ($hide) = $html =~ /data-ui-multi-hide="([^"]*)"/;
	is_deeply(main::convert_from_json(decode_attr($hide)), [ '1' ],
		'hiding modes passed to the script as JSON strings');
	like($html, qr/ui_multi_modes"[^>]*>(?:(?!<\/div>).)*<span (?=[^>]*\bui_multi_count\b)[^>]*>2 selected</s,
		'count of chosen entries next to the mode select');
	like(main::ui_multi_select_list('x', [ 'a' ], [ [ 'a', 'A' ] ]),
		qr/ui_multi_tools"[^>]*>(?:(?!ui_multi_list).)*<span (?=[^>]*\bui_multi_count\b)[^>]*>1 selected</s,
		'count in the toolbar when there are no modes');
	like(main::ui_multi_select_list('x', [ ], [ [ 'a', 'A' ] ]),
		qr/<span (?=[^>]*\bui_multi_count\b)(?=[^>]*\bhidden\b)/,
		'count hidden while nothing is chosen');
	like($html, qr/<span (?=[^>]*\bui_multi_count\b)(?=[^>]*\bhidden\b)/,
		'count hidden under a mode that leaves the list out of use');
	like($html, qr/<div (?=[^>]*\bui_multi_body\b)(?=[^>]*\bhidden\b)/,
		'list hidden under a mode that does not use it');
	unlike($html, qr/\bhidden\b[^>]*\bui_multi_item\b|\bui_multi_item\b[^>]*\bhidden\b/,
		'every entry is shown, nothing folds');
	unlike(main::ui_multi_select_list('x', [ ], [ [ 'a', 'A' ] ]),
		qr/ui_search/, 'short list has no filter box');
	like(main::ui_multi_select_list('x', [ ], [ map { [ $_, $_ ] } 1..9 ]),
		qr/ui_search/, 'long list has one');
	like(main::ui_multi_select_list('x', [ ], [ [ 'a', 'A' ] ],
		{ 'modes' => { 'name' => 'all', 'value' => 1, 'radios' => 1,
			       'options' => [ [ 1, 'All' ], [ 0, 'Some' ] ] } }),
		qr/type='radio'[^>]*name="all"/, 'modes can be radios');
	like(main::ui_multi_select_list('x', [ ], [ [ 'a', 'A' ] ],
		{ 'height' => '200px' }),
		qr/--ui-multi-height:200px/, 'height option sets the scroll height');
	like(main::ui_multi_select_list('g', [ 'a' ],
		[ [ 'a', 'A' ], [ 'b', 'B' ] ], 5, 1, 1),
		qr/value="a"[^>]*disabled/,
		'disabled of ui_multi_select_list disables the rows');
}

# Short pickers need neither bulk links nor the default filter.
{
	foreach my $size (1, 8, 9) {
		my $html = main::ui_multi_select_list('size', [],
			[ map { [ $_, $_ ] } 1..$size ]);
		is(scalar(() = $html =~ /data-ui-multi-action="(?:all|invert)"/g),
			$size > 8 ? 2 : 0, "$size entries: bulk link threshold");
		is(scalar(() = $html =~ /data-ui-multi-search="1"/g),
			$size > 8 ? 1 : 0, "$size entries: default search threshold");
		}
	unlike(main::ui_multi_select_list('short_search', [], [ [ 'a', 'A' ] ],
		{ 'search' => 1 }), qr/data-ui-multi-action="(?:all|invert)"/,
		'explicit search does not add bulk links to a short list');
	my $html = main::ui_multi_select_list('short_mode', [], [ [ 'a', 'A' ] ],
		{ 'modes' => { 'name' => 'mode', 'value' => 0,
			'options' => [ [ 0, 'Selected' ], [ 1, 'All' ] ] } });
	unlike($html, qr/ui_multi_tools/, 'mode-only pickers omit the empty toolbar');
}

# Omitting the counter preserves selections and the remaining controls.
{
	my $short = main::ui_multi_select_list('quiet', [ 'a' ], [ [ 'a', 'A' ] ],
		{ 'count' => 0 });
	unlike($short, qr/ui_multi_count|ui_multi_tools/,
		'counter-free short lists have no empty toolbar');
	like($short, qr/type='hidden'[^>]*name="quiet"[^>]*value="a"/,
		'counter-free lists retain their submitted selection');
	my $modes = main::ui_multi_select_list('quiet_mode', [ 'a' ], [ [ 'a', 'A' ] ],
		{ 'count' => 0, 'modes' => { 'name' => 'mode', 'value' => 0,
			'options' => [ [ 0, 'Selected' ], [ 1, 'All' ] ] } });
	unlike($modes, qr/ui_multi_count|ui_multi_tools/,
		'counter-free mode selectors have no counter or empty toolbar');
	like($modes, qr/<select [^>]*name="mode"/,
		'the mode selector remains available without a counter');
	my $long = main::ui_multi_select_list('quiet_long', [ 1 ],
		[ map { [ $_, $_ ] } 1..9 ], { 'count' => 0 });
	unlike($long, qr/ui_multi_count/, 'long lists can also omit the counter');
	like($long, qr/data-ui-multi-action="all"/,
		'counter-free long lists retain bulk selection');
	like($long, qr/data-ui-multi-search="1"/,
		'counter-free long lists retain filtering');
}

# Legacy attributes must retain row presentation and checkbox behavior.
{
	my $tags = q{DISABLED="false" class="managed" style='font-style:italic' title="Policy &amp; owner" data-policy=managed};
	my @options = ( [ 'locked', 'Locked', $tags ],
		[ 'open', 'Open', q{title="This is not disabled" data-note='a=b > c'} ] );
	my $html = main::ui_multi_select_list('attrs', [ 'locked' ], \@options);
	like($html, qr/<input (?=[^>]*value="locked")(?=[^>]*\bchecked\b)(?=[^>]*\bdisabled\b)/,
		'legacy boolean disabled locks a selected checkbox, even with value false');
	like($html, qr/name="attrs"[^>]*value="locked"/,
		'disabled selections retain their submitted values');
	like($html, qr/<div (?=[^>]*\bui_multi_item\b)(?=[^>]*\bui_multi_disabled\b)(?=[^>]*\bmanaged\b)/,
		'legacy classes combine with the widget and disabled row classes');
	like($html, qr/<div (?=[^>]*\bui_multi_item\b)(?=[^>]*style="font-style:italic")/,
		'legacy styles apply to the whole row');
	like($html, qr/title="Policy &amp; owner"/,
		'legacy title entities are preserved without double escaping');
	like($html, qr/data-policy="managed"/,
		'unquoted data attributes survive normalization');
	unlike($html, qr/<input (?=[^>]*value="open")(?=[^>]*\bdisabled\b)/,
		'disabled inside a quoted attribute does not disable the checkbox');
	like($html, qr/data-note="a=b > c"/,
		'quoted attribute values retain spaces, equals and greater-than signs');
	is($options[0]->[2], $tags, 'normalization does not modify legacy tags');
	foreach my $disabled ( 'disabled', "disabled='disabled'", 'disabled=disabled' ) {
		like(main::ui_multi_select_list('d', [ ], [ [ 'a', 'A', $disabled ] ]),
			qr/<input (?=[^>]*value="a")(?=[^>]*\bdisabled\b)/,
			"checkbox honors $disabled");
		}
	my $attrs = { 'disabled' => undef, 'title' => 'Managed', 'class' => 'managed' };
	my $hash = main::ui_multi_select_list('hashattrs', [ ],
		[ { 'value' => 'a', 'label' => 'A', 'attrs' => $attrs } ]);
	like($hash, qr/<input (?=[^>]*value="a")(?=[^>]*\bdisabled\b)/,
		'hash attributes also disable the checkbox');
	is_deeply($attrs, { 'disabled' => undef, 'title' => 'Managed', 'class' => 'managed' },
		'normalization does not modify the caller attribute hash');
	my $missing = main::ui_multi_select_list('missing',
		[ [ 'gone', 'Gone', q{disabled title='Retained'} ] ], [ ]);
	like($missing, qr/<input (?=[^>]*value="gone")(?=[^>]*\bchecked\b)(?=[^>]*\bdisabled\b)/,
		'missing selected values retain their legacy disabled attribute');
	like($missing, qr/title="Retained"/, 'missing values retain row attributes');
	my $fixed = main::ui_multi_select_list('fixed', [ ],
		[ [ 'a', 'A', q{checked name=wrong value=wrong type=radio} ] ]);
	like($fixed, qr/<input (?=[^>]*type='checkbox')(?=[^>]*name="fixed_item")(?=[^>]*value="a")/,
		'row attributes cannot replace checkbox identity');
	unlike($fixed, qr/<input (?=[^>]*value="a")(?=[^>]*\bchecked\b)/,
		'row attributes cannot override the selected values');
	my @disabled;
	{
		no warnings qw(redefine once);
		local *main::theme_ui_checkbox = sub { push(@disabled, $_[5]); return ''; };
		main::ui_multi_select_list('themed', [ ], \@options);
	}
	is_deeply(\@disabled, [ 1, 0 ], 'themes receive the normalized disabled state');
}

# Three-argument callers retain legacy selected labels and order.
{
	my $values = [ [ 'b', 'Selected &amp; saved' ], [ 'a', 'A' ] ];
	my $options = [ [ 'a', 'R&amp;D' ], [ 'b', 'Available' ] ];
	my $html = main::ui_multi_select_list('short', $values, $options);
	like($html, qr/name="short"[^>]*value="b\na"/,
		'omitting size preserves the supplied selection order');
	like($html, qr/>Selected &amp; saved</,
		'omitting size preserves the selected description and escaped text');
}

# Trusted HTML is opt-in and filtering uses the displayed label text.
{
	my $label = '<i title="a > b">Entire website &amp; files</i>';
	my $options = [ { 'value' => 'root', 'label' => $label,
		'suffix' => '<suffix>', 'tag' => '<tag>' } ];
	my $plain = main::ui_multi_select_list('plain', [ 'root' ], $options, {});
	like($plain, qr/&lt;i title&#61;/, 'labels are escaped by default');
	unlike($plain, qr/<i\b/, 'default labels cannot introduce markup');
	my $html = main::ui_multi_select_list('markup',
		[ 'root', [ 'missing', '<b>Missing &amp;lt;path&amp;gt;</b>' ] ],
		$options, { 'html' => 1 });
	like($html, qr/\Q$label\E/, 'the HTML flag retains trusted label markup');
	like($html, qr/aria-label="Entire website &amp; files"/,
		'HTML labels retain an accessible checkbox name');
	like($html, qr/<b>Missing &amp;lt;path&amp;gt;<\/b>/,
		'missing selections also support trusted HTML labels');
	like($html, qr/&lt;suffix&gt;/, 'HTML labels do not enable HTML suffixes');
	like($html, qr/&lt;tag&gt;/, 'HTML labels do not enable HTML tags');
	my @filter = $html =~ /data-ui-multi-text="([^"]*)"/g;
	is_deeply([ map { decode_attr($_) } @filter ],
		[ 'Entire website & files<suffix> <tag>', 'Missing &lt;path&gt;' ],
		'filter text removes markup and decodes entities only once');
	like($html, qr/name="markup"[^>]*value="root\nmissing"/,
		'HTML labels do not change submitted values');
	assert_no_handler_injection(main::ui_multi_select_list('safe', [ $xss ],
		[ { 'value' => $xss, 'label' => '<b>Trusted</b>',
		    'suffix' => $xss, 'tag' => $xss } ], { 'html' => 1 }),
		'HTML mode value and metadata');
}

# Positional calls preserve the old selected pane's labels and value order.
{
	my @values = ( [ 'b', 'B (selected)', q{disabled title="Selected"} ],
		[ 'a', 'R&amp;D' ], [ 'gone', 'Missing', q{title="Retained"} ] );
	my @options = ( [ 'a', 'A', 'disabled' ], [ 'b', 'B' ],
		[ 'c', 'C', 'disabled' ] );
	my $html = main::ui_multi_select_list('legacy', \@values, \@options, 5, 1);
	my $old = main::ui_multi_select('legacy', \@values, \@options, 5);
	my ($value) = $html =~ /type='hidden'[^>]*name="legacy"[^>]*value="([^"]*)"/;
	my ($oldvalue) = $old =~ /type='hidden'[^>]*name="legacy"[^>]*value="([^"]*)"/;
	is($value, $oldvalue, 'legacy submitted order matches the old widget');
	my ($order) = $html =~ /data-ui-multi-order="([^"]*)"/;
	is($order, '', 'legacy order is captured from the initial hidden input');
	like($html, qr/>B \(selected\)</, 'legacy selected description overrides the option label');
	like($html, qr/>R&amp;D</, 'legacy pre-escaped labels are not double escaped');
	my ($filter) = $html =~ /data-ui-multi-text="(R[^"]*)"/;
	is(decode_attr($filter), 'R&D', 'legacy filter text matches the visible label');
	like($html, qr/<input (?=[^>]*value="b")(?=[^>]*\bdisabled\b)/,
		'legacy selected attributes disable existing entries');
	unlike($html, qr/<input (?=[^>]*value="a")(?=[^>]*\bdisabled\b)/,
		'selected attributes take precedence over available option attributes');
	like($html, qr/<input (?=[^>]*value="c")(?=[^>]*\bdisabled\b)/,
		'unselected entries keep their option attributes');
	like($html, qr/title="Selected"/, 'legacy selected row keeps its tooltip');
	like($html, qr/title="Retained"/, 'missing legacy selection keeps its tooltip');
	is_deeply(\@values, [ [ 'b', 'B (selected)', q{disabled title="Selected"} ],
		[ 'a', 'R&amp;D' ], [ 'gone', 'Missing', q{title="Retained"} ] ],
		'legacy selected entries are not modified');
	is_deeply(\@options, [ [ 'a', 'A', 'disabled' ], [ 'b', 'B' ],
		[ 'c', 'C', 'disabled' ] ], 'legacy options are not modified');
	my $numeric = main::ui_multi_select_list('numeric', [ [ 2, 'Two' ], [ 1, 'One' ] ],
		[ [ 1, 'One' ], [ 2, 'Two' ] ], 5);
	like($numeric, qr/name="numeric"[^>]*value="2\n1"/,
		'numeric selection IDs retain their original order');
	assert_no_handler_injection(main::ui_multi_select_list('legacy_xss',
		[ [ 'a', $xss ] ], [ [ 'a', 'A' ] ], 5), 'legacy selected label');
	my $modern = main::ui_multi_select_list('modern', [ [ 'b', 'B.x' ], [ 'a', 'A' ] ],
		[ [ 'a', 'R&amp;D' ], { 'value' => 'b', 'label' => 'B', 'suffix' => '.x' } ], {});
	unlike($modern, qr/data-ui-multi-order=/, 'options-hash calls retain the modern ordering policy');
	like($modern, qr/name="modern"[^>]*value="a\nb"/, 'modern selections follow option order');
	like($modern, qr/>R&amp;amp;D</, 'modern labels retain literal entity text');
	like($modern, qr/>B<\/label><span[^>]*>\.x</, 'modern option labels retain their suffix without duplication');
}

# Preserve UTF-8 bytes and literal entities for browser-side matching.
{
	my $label = "\xC3\x89QUIPE";
	my $html = main::ui_multi_select_list('g', [ ],
		[ [ 'team', $label ] ], { 'search' => 1 });
	my ($filter) = $html =~ /data-ui-multi-text="([^"]*)"/;
	is($filter, $label, 'filter label retains original UTF-8 bytes and case');
	my $literal = 'R&amp;D';
	$html = main::ui_multi_select_list('g', [ ], [ [ 'team', $literal ] ], {});
	($filter) = $html =~ /data-ui-multi-text="([^"]*)"/;
	is(decode_attr($filter), $literal,
		'filter text preserves literal HTML entity names in plain labels');
}
assert_no_handler_injection(
	main::ui_multi_select_list($xss, [ $xss ],
		[ { 'value' => $xss, 'label' => $xss, 'suffix' => $xss,
		    'tag' => $xss } ],
		{ 'placeholder' => $xss, 'search' => 1 }),
	'ui_multi_select_list');

# Filter accessibility, visibility and disabled state.
{
	my $html = main::ui_multi_select_list('filter', [ ], [ [ 'a', 'A' ] ],
		{ 'search' => 1 });
	like($html, qr/<button (?=[^>]*type="button")(?=[^>]*data-ui-multi-action="filter")(?=[^>]*aria-expanded="false")(?=[^>]*aria-controls="filter_search")(?=[^>]*aria-label="Filter content")/,
		'filter starts collapsed with an accessible toggle button');
	like($html, qr/<button (?=[^>]*type="button")(?=[^>]*data-ui-multi-action="filter-clear")(?=[^>]*aria-label="Clear or close filter")/,
		'filter has a labelled clear button that cannot submit the form');
	like($html, qr/<input (?=[^>]*type="search")(?=[^>]*id="filter_search")(?=[^>]*aria-label="Filter content")/,
		'search input is labelled and targeted by its buttons');
	unlike(main::ui_multi_select_list('filter', [ ],
		[ map { [ $_, $_ ] } 1..9 ], { 'search' => 0 }),
		qr/data-ui-multi-search/, 'search can still be explicitly hidden');
	my $disabled = main::ui_multi_select_list('filter', [ ], [ [ 'a', 'A' ] ],
		{ 'search' => 1, 'disabled' => 1 });
	is(scalar(() = $disabled =~ /<(?:button|input) (?=[^>]*(?:data-ui-multi-action="filter(?:-clear)?"|data-ui-multi-search="1"))(?=[^>]*\bdisabled\b)/g), 3,
		'disabled pickers disable the input and both filter buttons');
}

# Mode radio labels are plain text.
assert_no_handler_injection(
	main::ui_multi_select_list('d', [ ], [ [ 'a', 'A' ] ],
		{ 'modes' => { 'name' => 'mode', 'value' => 'some', 'radios' => 1,
			       'options' => [ [ 'some', $xss ], [ 'all', 'All' ] ] } }),
	'ui_multi_select_list mode radios');

# Hidden-mode values must survive attribute encoding intact.
{
	my @hide = ( 'all servers', '', '&quot;', "line\nbreak" );
	my $html = main::ui_multi_select_list('d', [ ], [ [ 'a', 'A' ] ],
		{ 'modes' => { 'name' => 'mode', 'value' => 'all servers',
			       'options' => [ map { [ $_, $_ ] } @hide ],
			       'hide' => \@hide } });
	my ($hide) = $html =~ /data-ui-multi-hide="([^"]*)"/;
	is_deeply(main::convert_from_json(decode_attr($hide)), \@hide,
		'hidden-mode values survive attribute encoding without splitting');
}

# Empty pickers retain form values without visible controls.
{
	my $opts = { 'search' => 1,
		'modes' => { 'name' => 'all', 'value' => 2,
			     'options' => [ [ 1, 'All' ], [ 2, 'Except' ] ] },
		'children' => { 'name' => 'sub', 'checked' => 1, 'value' => 'yes' } };
	my $html = main::ui_multi_select_list('d', [ ], [ ], $opts);
	like($html, qr/^<span class="ui--span">No entries<\/span>/,
		'an empty picker is a plain span without empty-state styling');
	unlike($html, qr/<(?:select|button|label|a|div|link|script)\b|type=['"](?:checkbox|radio|search)['"]|\bui_multi_(?:tools|list)\b/,
		'no controls, wrapper or assets are emitted, even when search is requested');
	like($html, qr/type='hidden'[^>]*name="d"[^>]*value=""/,
		'an empty picker still submits an empty selection');
	like($html, qr/type='hidden'[^>]*name="all"[^>]*value="2"/,
		'the saved mode is retained without a visible selector');
	like($html, qr/type='hidden'[^>]*name="sub"[^>]*value="yes"/,
		'the checked children option retains its submitted value');
	unlike($html, qr/\bdata-ui-multi=/,
		'the static empty label needs no JavaScript initialization');
	my $disabled = main::ui_multi_select_list('d', [ ], [ ],
		{ %$opts, 'disabled' => 1 });
	unlike($disabled, qr/name="(?:all|sub)"/,
		'disabled mode and children controls remain excluded from submission');
	my $label = 'No virtual servers have been created yet';
	like(main::ui_multi_select_list('d', [ ], [ ], { 'empty_label' => $label }),
		qr/^<span class="ui--span">\Q$label\E<\/span>/,
		'caller can supply a plain empty label');
	like(main::ui_multi_select_list('d', [ ], [ ], { 'empty_label' => '<b>None & none</b>' }),
		qr/&lt;b&gt;None &amp; none&lt;\/b&gt;/,
		'custom empty label is escaped as plain text');
	assert_no_handler_injection(
		main::ui_multi_select_list('d', [ ], [ ], { 'empty_label' => $xss }),
		'custom empty label');
}

# Add missing saved values only once.
{
	my $html = main::ui_multi_select_list('d', [ 'gone', 'gone' ], [ ]);
	is(scalar(() = $html =~ /\bclass="[^"]*\bui_multi_item\b/g), 1,
		'a missing selected entry is added once');
	unlike($html, qr/>No entries</,
		'saved values absent from the options still make a populated picker');
}

# Folding hides children and shows their count beside the parent.
{
	my @opts = ( [ 'p', 'Parent' ],
		     { 'value' => 'c1', 'label' => 'One', 'level' => 1 },
		     { 'value' => 'c2', 'label' => 'Two', 'level' => 1 } );
	# $1 expands to the child count.
	$main::text{'ui_multi_test_note'} = '+$1 kids';
	my $html = main::ui_multi_select_list('d', [ 'p' ], \@opts,
		{ 'children' => { 'name' => 'sub', 'checked' => 1,
				  'label' => 'With children',
				  'note' => 'ui_multi_test_note' } });
	like($html, qr/\bui_toggle\b/, 'the switch is a toggle');
	like($html, qr/<input (?=[^>]*\bname="sub")(?=[^>]*\bdata-ui-multi-action="children")(?=[^>]*\bchecked\b)/,
		'switch rendered on with its action');
	my @folded = $html =~ /(<div (?=[^>]*\bui_multi_item\b)(?=[^>]*\bhidden\b)[^>]*>)/g;
	is(scalar(@folded), 2, 'indented entries fold away while on');
	like($html, qr/<span (?=[^>]*\bui_multi_note\b)[^>]*>\+2 kids</,
		'parent row counts its children through the language');
	unlike(main::ui_multi_select_list('d', [ 'p' ], \@opts,
		{ 'children' => { 'name' => 'sub', 'label' => 'With children' } }),
		qr/ui_multi_note/, 'no note without a key for it');
	unlike($html, qr/<span (?=[^>]*\bui_multi_note\b)(?=[^>]*\bhidden\b)/,
		'count shown while on');
	my $open = main::ui_multi_select_list('d', [ 'p' ], \@opts,
		{ 'children' => { 'name' => 'sub', 'label' => 'With children',
				  'note' => 'ui_multi_test_note' } });
	my @shown = $open =~ /(<div (?=[^>]*\bui_multi_item\b)(?=[^>]*\bhidden\b)[^>]*>)/g;
	is(scalar(@shown), 0, 'entries shown while off');
	like($open, qr/<span (?=[^>]*\bui_multi_note\b)(?=[^>]*\bhidden\b)/,
		'count hidden while off');

	# Initial counts must match JavaScript without losing folded selections.
	my $selected = [ 'p', 'c1', 'c2' ];
	my $closed = main::ui_multi_select_list('d', $selected, \@opts,
		{ 'children' => { 'name' => 'sub', 'checked' => 1 } });
	like($closed, qr/<span (?=[^>]*\bui_multi_count\b)[^>]*>1 selected</,
		'folded count includes only the selected parent');
	like($closed, qr/type='hidden'[^>]*name="d"[^>]*value="p\nc1\nc2"/,
		'folded children retain their submitted selections');
	my $expanded = main::ui_multi_select_list('d', $selected, \@opts,
		{ 'children' => { 'name' => 'sub' } });
	like($expanded, qr/<span (?=[^>]*\bui_multi_count\b)[^>]*>3 selected</,
		'expanded count includes selected children');
	my $only_children = main::ui_multi_select_list('d', [ 'c1' ], \@opts,
		{ 'children' => { 'name' => 'sub', 'checked' => 1 } });
	like($only_children, qr/<span (?=[^>]*\bui_multi_count\b)(?=[^>]*\bhidden\b)[^>]*>0 selected</,
		'count is hidden when only folded children are selected');
	like($only_children, qr/type='hidden'[^>]*name="d"[^>]*value="c1"/,
		'folding retains child selections even without a selected parent');
}

done_testing();
