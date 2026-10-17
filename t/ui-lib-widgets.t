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

# A decoded value elsewhere on the page must not double-encode the note icon.
{
	my $decoded = 'efi';
	utf8::upgrade($decoded);
	foreach my $prefix ('efi', $decoded) {
		my $html = $prefix.main::ui_note('Note', 0);
		# Model the UTF-8 response bytes and the browser's decoding step.
		utf8::encode($html) if (utf8::is_utf8($html));
		utf8::decode($html);
		like($html, qr/(?:\x{24d8}|&#9432;|&#x24d8;)/i,
			'ui_note icon survives byte and decoded page strings');
		}
	my $html = main::ui_note("Note \x{20ac}", 0);
	like($html, qr/(?:\x{24d8}|&#9432;|&#x24d8;)/i,
		'ui_note icon survives decoded note text');
	like($html, qr/Note \x{20ac}/, 'ui_note preserves decoded note text');
}

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
assert_no_handler_injection(
	main::ui_badge('B', 'success', { 'class' => $xss, 'title' => $xss }),
	'ui_badge class+title');
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

# Row defaults must not replace explicit tile shapes or mutate input options.
{
	my $tile = { 'value' => 4 };
	my $square = { 'value' => 2, 'shape' => 'square' };
	my $html = main::ui_stats([$tile, $square], { 'shape' => 'rounded' });
	my @shapes = $html =~ /\bui_stat_(rounded|square)\b/g;
	is_deeply(\@shapes, ['rounded', 'square'],
		'ui_stats applies its shape only when a tile has no override');
	is_deeply($tile, { 'value' => 4 }, 'ui_stats preserves caller options');
	like(main::ui_stat({ 'value' => 1 }), qr/\bui_stat_square\b/,
		'ui_stat defaults to square corners');
	$html = main::ui_stat({ 'value' => 1, 'shape' => $xss });
	like($html, qr/\bui_stat_square\b/, 'unknown shapes fall back to square');
	assert_no_handler_injection($html, 'ui_stat shape');
}

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

# Badges take a smaller size, rounded ends and extra class names
{
	my $plain = main::ui_badge('B', 'info');
	unlike($plain, qr/ui_badge_small|ui_badge_rounded/,
		'a badge is full-sized and square by default');
	my $html = main::ui_badge('B', 'info',
		{ 'small' => 1, 'rounded' => 1, 'class' => 'mine' });
	like($html, qr/\bui_badge_small\b/, 'small option adds its class');
	like($html, qr/\bui_badge_rounded\b/, 'rounded option adds its class');
	like($html, qr/\bui_badge_info\b/, 'and the state class stays');
	like($html, qr/\bmine\b/, 'extra class names are passed through');
}

# Action controls retain native semantics and use the theme's button classes.
subtest 'action buttons and links' => sub {
	my $button = main::ui_action_button('Save', 'ok');
	like($button, qr/<button\b[^>]*type="button"/, 'default button does not submit');
	like($button, qr/\bui_action_success\b/, 'state aliases match badges');
	like($button, qr/\bbtn\b.*\bbtn-success\b/,
		'theme classes match the normalized state');
	unlike($button, qr/\b(?:ui_badge|ui_button|ui_submit|ui_link)\b/,
		'unrelated legacy classes are absent');
	foreach my $case (
		[ undef, 'btn-default' ], [ 'success', 'btn-success' ],
		[ 'warning', 'btn-warning' ], [ 'danger', 'btn-danger' ],
		[ 'info', 'btn-info' ], [ 'primary', 'btn-info' ]) {
		my ($state, $class) = @{$case};
		like(main::ui_action_button('Action', $state),
			qr/\b\Q$class\E\b/,
			($state || 'neutral').' uses its theme class');
		}
	my $opts = { type => 'submit', name => 'action', value => '', form => 'editor',
		size => 'small', shape => 'pill', icon => 'trash',
		attrs => { 'data-ui-confirm' => 'Proceed?', class => 'extra' } };
	my $submit = main::ui_action_button('Delete', 'danger', $opts);
	like($submit, qr/type="submit"/, 'submit is explicit');
	like($submit, qr/name="action"/, 'submitter name is preserved');
	like($submit, qr/value=""/, 'empty submitter value is preserved');
	like($submit, qr/form="editor"/, 'external form association is preserved');
	like($submit, qr/\bui_action_small\b.*\bui_action_pill\b.*\bextra\b/,
		'size, shape and caller classes combine');
	like($submit, qr/\bbtn-xs\b/, 'small actions use the theme size class');
	like($submit, qr/data-ui-confirm="Proceed\?"/, 'confirmation uses the shared handler');
	like($submit, qr/<svg\b/, 'explicit icon is rendered');
	is_deeply($opts->{'attrs'}, { 'data-ui-confirm' => 'Proceed?', class => 'extra' },
		'caller attributes are not modified');
	like(main::ui_action_button('Reset', undef, {type => 'reset'}),
		qr/type="reset"/, 'reset is supported');
	like(main::ui_action_button('Zero', undef, {value => 0}),
		qr/value="0"/, 'zero value is preserved');
	my $link = main::ui_action_button('Open', 'info',
		{ href => 'edit.cgi?id=1&tab=disks', type => 'submit' });
	like($link, qr/<a\b[^>]*href="edit.cgi\?id=1&amp;tab=disks"/, 'link has a normal URL');
	unlike($link, qr/\btype=/, 'link has no button type');
	my $disabled = main::ui_action_button('Open', 'info',
		{ href => 'edit.cgi', disabled => 1, attrs => {href => 'other.cgi'} });
	unlike($disabled, qr/\bhref=/, 'disabled link has no destination');
	like($disabled, qr/aria-disabled="true"/, 'disabled link exposes its state');
	like($disabled, qr/tabindex="-1"/, 'disabled link is outside keyboard navigation');
	like($disabled, qr/role="link"/, 'disabled anchor retains link semantics');
	like(main::ui_action_button('Disabled', undef, {disabled => 1}),
		qr/<button\b[^>]*\bdisabled(?:\s|>)/, 'button uses native disabled behavior');
	my $fallback = main::ui_action_button('Fallback', 'unknown',
		{type => 'invalid', size => 'invalid', shape => 'invalid', attrs => {type => 'submit'}});
	like($fallback, qr/\bui_action_neutral\b.*\bui_action_normal\b.*\bui_action_square\b/,
		'unknown variants use defaults');
	like($fallback, qr/type="button"/, 'unknown type cannot accidentally submit');
	unlike(main::ui_action_button('Plain', 'danger', {icon => ''}), qr/<svg\b/,
		'empty icon suppresses the state icon');
	assert_no_handler_injection(main::ui_action_button($xss, 'danger',
		{ href => $xss, title => $xss, class => $xss, name => $xss, value => $xss }),
		'action text and attributes');
};

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
	like(main::ui_dl([ { 'label_html' => '<i>L</i>', 'value' => 'v' } ]),
		qr/<dt[^>]*><i>L<\/i><\/dt>/, 'hash row label_html is HTML');
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

# Separate multi-select badges retain plain-text escaping and filter metadata.
{
	my $html = main::ui_multi_select_list('images', [ 'linux' ], [
		{ value => 'linux', label => '<b>Linux</b>', tag => 'QCOW2', badges => [
			[ 'ARM64', 'neutral', { small => 1, rounded => 1 } ],
			[ $xss, 'warning', { small => 1, rounded => 1 } ] ] },
	], { html => 1 });
	my @badges = $html =~ /class="[^"\n]*\bui_badge\b[^"\n]*"/g;
	is(scalar(@badges), 2, 'each metadata badge is a separate element');
	ok(!grep(!/ui_badge_small.*ui_badge_rounded/, @badges),
		'badge rendering retains size and shape options');
	like($html, qr/ui_chip"><span class="[^"]*\bui_chip_text">QCOW2</, 'plain tags still work beside badges');
	my ($filter) = $html =~ /data-ui-multi-text="([^"]*)"/;
	is(decode_attr($filter), 'Linux QCOW2 ARM64 '.$xss,
		'filtering includes every badge label as plain text');
	like($html, qr/value="linux"[^>]*checked/, 'badges do not alter selection');
	assert_no_handler_injection($html, 'multi-select badges with HTML labels');
}

# Grouped metadata stays plain text and preserves values and legacy defaults.
{
	my $group = { label => $xss, state => 'success', icon => 'star' };
	my @options = (
		{ value => 'a', label => 'First', group => $group, metadata => [
			{ label => '10 GiB', icon => 'hard-drive', title => $xss },
			{ label => $xss, icon => 'clock', state => 'warning' } ] },
		{ value => 'b', label => 'Second', group => $group },
		{ value => 'c', label => 'Third', group => { label => 'Older', state => 'warning' } },
	);
	my $html = main::ui_multi_select_list('grouped', [ 'b', 'a' ], \@options,
		{ compact => 1, search => 1, summary => $xss, summary_icon => 'download' });
	is(scalar(() = $html =~ /data-ui-multi-heading=/g), 2, 'consecutive options share a heading');
	is(scalar(() = $html =~ /class="[^"]*\bui_multi_metadata\b/g), 1, 'metadata facts share one badge');
	is(scalar(() = $html =~ /class="[^"]*\bui_multi_item\b/g), 3, 'headings are not selectable options');
	like($html, qr/ui_multi_compact/, 'compact layout is explicitly enabled');
	like($html, qr/name="grouped"[^>]*value="a\nb"/, 'grouping retains normal submission order');
	my ($filter) = $html =~ /data-ui-multi-text="([^"]*)"/;
	like(decode_attr($filter), qr/First.*\Q$xss\E.*10 GiB.*\Q$xss\E/s,
		'group names and metadata tooltips are searchable');
	assert_no_handler_injection($html, 'group names, summary and metadata');
	ok(!exists($options[0]->{'attrs'}), 'group rendering does not mutate input options');
	my $plain = main::ui_multi_select_list('plain', [], [ [ 'a', 'First' ] ], {});
	unlike($plain, qr/ui_multi_compact|data-ui-multi-group|data-ui-multi-heading|ui_multi_metadata/,
		'existing callers opt into none of the new layout');
}

# Metadata tooltips treat entity names as literal text, like their filter text.
{
	my $title = 'Literal &amp; <tip> "quoted"';
	my $html = main::ui_multi_select_list('literal_metadata', [],
		[{ value => 'a', label => 'First', metadata => [{ label => 'Details', title => $title }] }], {});
	my ($tooltip) = $html =~ /<span (?=[^>]*\bui_multi_meta\b)[^>]*\btitle="([^"]*)"/;
	is(decode_attr($tooltip), $title, 'metadata tooltip retains literal entity text');
	my ($filter) = $html =~ /data-ui-multi-text="([^"]*)"/;
	is(decode_attr($filter), 'First Details '.$title, 'metadata filtering matches the tooltip text');
}

# Hiding bulk actions must retain the summary and automatic filter on long lists.
{
	my $html = main::ui_multi_select_list('no_bulk', [],
		[ map { [ $_, "Option $_" ] } 1..9 ],
		{ bulk => 0, count => 0, summary => $xss, summary_icon => 'star' });
	unlike($html, qr/data-ui-multi-action="(?:all|invert)"/,
		'bulk option hides selection links on long lists');
	like($html, qr/data-ui-multi-search="1"/, 'bulk option preserves filtering');
	like($html, qr/ui_multi_summary/, 'summary remains visible without a counter');
	assert_no_handler_injection($html, 'summary without bulk actions');
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
	like($html, qr/ui_chip"><span class="[^"]*\bui_chip_text">Plan</, 'tag is a chip');
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

# Checkbox lists load their assets once per request, including on ordinary forms.
{
	local $main::ui_page_assets_done = 0;
	my $html = main::ui_multi_select_list('first', [], [ [ 'a', 'A' ] ], 5);
	like($html, qr/data-ui-multi="first"/, 'positional list calls render checkboxes');
	like($html, qr/ui-lib\.css/, 'lists load the widget stylesheet');
	like($html, qr/ui-lib\.js/, 'lists load the delegated widget script');
	unlike(main::ui_multi_select_list('second', [], [ [ 'b', 'B' ] ], 5),
		qr/ui-lib\.(css|js)/, 'another picker does not reload the assets');
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

# Each widget has its own theme entry point.
{
	no warnings qw(redefine once);
	my @received;
	local *main::theme_ui_multi_select_list = sub { @received = @_; return 'themed'; };
	local *main::theme_ui_multi_select = sub { return 'dual-list'; };
	foreach my $args ([ 'theme', [], [], 5, 1, 1, 'Available', 'Selected', 300 ],
			 [ 'theme', [], [], { 'search' => 1 } ]) {
		is(main::ui_multi_select_list(@$args), 'themed', 'the checkbox-list theme hook is used');
		is_deeply(\@received, $args, 'the theme receives the original arguments');
		}
	is(main::ui_multi_select('old', [], [], 5), 'dual-list',
		'the original widget retains its separate theme hook');
}

# The original widget retains dual selects, titles, size, width and script loading.
{
	no warnings 'once';
	local $main::ui_multi_select_donejs = 0;
	my $html = main::ui_multi_select('old', [ [ 'b', 'Chosen B' ] ],
		[ [ 'a', 'Available A' ], [ 'b', 'Available B' ] ],
		7, 1, 0, 'Available', 'Selected', 300);
	like($html, qr/name="old_opts"[^>]*size='7'[^>]*min-width:300px/,
		'the available pane retains its size and width');
	like($html, qr/name="old_vals"[^>]*size='7'/,
		'the selected pane is restored');
	like($html, qr/<b>Available<\/b>.*<b>Selected<\/b>/s,
		'dual-list column titles are retained');
	like($html, qr/>Chosen B<\/option>/, 'selected labels retain their descriptions');
	like($html, qr/function multi_select_move/, 'the original move script is loaded');
	unlike($html, qr/data-ui-multi=/, 'the original widget does not render the checkbox list');
	unlike(main::ui_multi_select('old_second', [], [], 5),
		qr/function multi_select_move/, 'dual-list scripts load once per request');
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
	my ($value) = $html =~ /type='hidden'[^>]*name="legacy"[^>]*value="([^"]*)"/;
	is($value, "b\na\ngone", 'legacy submission retains the supplied selection order');
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

# Explicit widget IDs isolate labels and filters in forms sharing a field name.
{
	foreach my $id ('validate', 'schedule') {
		my $html = main::ui_multi_select_list('servers', ['a'], [['a', 'A']],
			{ 'id' => $id, 'search' => 1 });
		like($html, qr/id="${id}_item_a"/, "$id checkbox uses the widget ID");
		like($html, qr/for="${id}_item_a"/, "$id label targets its own checkbox");
		like($html, qr/id="${id}_search"/, "$id filter uses the widget ID");
		is(() = $html =~ /aria-controls="${id}_search"/g, 2,
			"$id filter buttons target their own input");
		like($html, qr/type='hidden'[^>]*name="servers"[^>]*value="a"/,
			"$id retains the submitted field name and selected value");
	}
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

# ---- menus, dialogs and navigation -----------------------------------------

# The script tag carries the texts of the confirmation dialog
{
	local $main::ui_page_assets_done = 0;
	my $assets = main::ui_page_assets();
	like($assets, qr/<script (?=[^>]*\bsrc="[^"]*ui-lib\.js)(?=[^>]*\bdata-ui-lib="1")(?=[^>]*\bdata-ui-text-confirm="Please confirm")(?=[^>]*\bdata-ui-text-ok="OK")(?=[^>]*\bdata-ui-text-cancel="Cancel")(?=[^>]*\bdata-ui-text-close="Close")/,
		'the confirmation texts ride on the script tag');
	is(main::ui_page_assets(), '', 'assets are emitted once');
}

# The icons the file manager and the menus draw with exist
foreach my $icon (qw(folder folder-plus file file-plus copy scissors clipboard
		     archive unarchive key tag lock link bookmark check-square
		     square-half cursor-text ellipsis menu home)) {
	like(main::ui_svg_icon($icon), qr/\bui_svg_icon_\Q$icon\E\b/, "icon $icon exists");
}
like(main::ui_svg_icon('ellipsis'), qr/fill="currentColor"/, 'ellipsis is drawn filled');

# Drop-down menus : a details element whose summary is an action button,
# with link and button entries, separators, headings and disabled entries
{
	my $html = main::ui_dropdown('File', [
		{ 'label' => 'New', 'icon' => 'file-plus', 'dialog' => 'd1' },
		{ 'label' => 'Open', 'href' => 'open.cgi?x=1&y=2', 'desc' => 'A file' },
		'-',
		{ 'heading' => 'Recent' },
		{ 'label' => 'Gone', 'href' => 'gone.cgi', 'disabled' => 1 },
		{ 'label' => 'Off', 'disabled' => 1 },
		{ 'label' => 'Remove', 'state' => 'danger',
		  'attrs' => { 'data-ui-confirm' => 'Sure?' } },
		{ 'label' => 'Send', 'type' => 'submit', 'name' => 'act', 'value' => 'send',
		  'form' => 'f1' },
		{ 'html' => '<i class="raw">raw</i>' },
		], { 'icon' => 'file', 'align' => 'end', 'id' => 'menu_file',
		     'width' => '14em' });
	like($html, qr/<details (?=[^>]*\bclass="[^"]*\bui_dropdown\b[^"]*\bui_dropdown_end\b)(?=[^>]*\bid="menu_file")(?=[^>]*\bdata-ui-dropdown="1")/,
		'menu is a details element with its alignment, id and marker');
	like($html, qr/<summary (?=[^>]*\bclass="[^"]*\bui_dropdown_toggle\b[^"]*\bui_action\b[^"]*\bui_action_neutral\b[^"]*\bui_action_normal\b[^"]*\bui_action_square\b)(?=[^>]*\brole="button")(?=[^>]*\baria-haspopup="menu")/,
		'summary is the button, drawn as an action button');
	like($html, qr/<summary [^>]*\bclass="[^"]*\bbtn\b[^"]*\bbtn-default\b/,
		'summary uses the native neutral theme button style');
	my $styled = main::ui_dropdown('More', [],
		{ 'state' => 'danger', 'size' => 'small' });
	like($styled, qr/<summary [^>]*\bclass="[^"]*\bbtn-danger\b[^"]*\bbtn-xs\b/,
		'summary maps its state and size to native theme classes');
	like($html, qr/ui_svg_icon_file\b.*?<span class="ui--span">File<\/span>.*?ui_dropdown_caret/s,
		'button shows its icon, label and arrow');
	like($html, qr/<div (?=[^>]*\bclass="[^"]*\bui_dropdown_menu\b")(?=[^>]*\brole="menu")(?=[^>]*\bstyle="min-width:14em")/,
		'entries sit in a menu panel of the asked width');
	like($html, qr/<button (?=[^>]*\btype="button")(?=[^>]*\bdata-ui-dialog="d1")(?=[^>]*\brole="menuitem")[^>]*>.*?ui_svg_icon_file-plus.*?<span class="[^"]*ui_dropdown_label">New</s,
		'an entry without a URL is a non-submitting button opening its dialog');
	like($html, qr/<a (?=[^>]*\bhref="open.cgi\?x=1&amp;y=2")(?=[^>]*\brole="menuitem")[^>]*>.*?<span class="[^"]*ui_dropdown_desc">A file</s,
		'an entry with a URL is a link, with its description line');
	like($html, qr/<hr [^>]*\bui_dropdown_sep\b/, 'a dash is a separator');
	like($html, qr/<div [^>]*\bui_dropdown_heading\b[^>]*>Recent</, 'a heading entry');
	like($html, qr/<a (?=[^>]*\baria-disabled="true")(?=[^>]*\btabindex="-1")(?![^>]*\bhref=)[^>]*>.*?Gone/s,
		'a disabled link loses its destination');
	like($html, qr/<button (?=[^>]*\bdisabled\b)[^>]*>.*?Off/s, 'a disabled button entry');
	like($html, qr/<button (?=[^>]*\bui_dropdown_danger\b)(?=[^>]*\bdata-ui-confirm="Sure\?")/,
		'state and extra attributes are kept');
	like($html, qr/<button (?=[^>]*\btype="submit")(?=[^>]*\bname="act")(?=[^>]*\bvalue="send")(?=[^>]*\bform="f1")/,
		'a submit entry keeps its form attributes');
	like($html, qr/<i class="raw">raw<\/i>/, 'raw entries are inserted as given');
	my $valued = main::ui_dropdown('Row', [
		{ 'label' => 'Rename', 'dialog' => 'd', 'values' => { 'name' => 'a "b"' } } ]);
	my ($values) = $valued =~ /data-ui-dialog-values="([^"]*)"/;
	is_deeply(main::convert_from_json(decode_attr($values)), { 'name' => 'a "b"' },
		'an entry opening a dialog can carry values for it');
	my $icon_only = main::ui_dropdown('', [ { 'label' => 'A' } ],
		{ 'title' => 'More', 'caret' => 0, 'icon' => 'ellipsis' });
	like($icon_only, qr/<summary (?=[^>]*\baria-label="More")(?=[^>]*\btitle="More")/,
		'an icon-only menu is named by its tooltip');
	unlike($icon_only, qr/ui_dropdown_caret/, 'the arrow can be left out');
	assert_no_handler_injection(main::ui_dropdown($xss, [
		{ 'label' => $xss, 'href' => $xss, 'desc' => $xss, 'title' => $xss },
		{ 'heading' => $xss }, { 'label' => $xss, 'dialog' => $xss } ],
		{ 'title' => $xss, 'id' => $xss, 'width' => $xss }), 'ui_dropdown text');
}

# Dialogs : a dialog element with a heading, a closing cross, a body,
# a footer and an optional form around them
{
	my $html = main::ui_dialog({
		'id' => 'd1', 'title' => 'Rename', 'desc' => 'Pick a name',
		'state' => 'danger', 'size' => 'small',
		'form' => { 'action' => 'rename.cgi', 'attrs' => { 'data-x' => '1' } },
		'body' => '<input name="name">',
		'footer' => '<button type="submit">Go</button>',
		'close' => 'Cancel' });
	like($html, qr/<dialog (?=[^>]*\bid="d1")(?=[^>]*\baria-labelledby="d1_title")(?=[^>]*\bclass="[^"]*\bui_dialog\b[^"]*\bui_dialog_small\b[^"]*\bui_dialog_danger\b)/,
		'dialog element with id, label, size and state');
	like($html, qr/<form (?=[^>]*\baction="rename.cgi")(?=[^>]*\bmethod="post")(?=[^>]*\bdata-x="1")(?=[^>]*\bui_dialog_form\b)/,
		'the form wraps the dialog and posts by default');
	like($html, qr/<h2 (?=[^>]*\bid="d1_title")[^>]*>.*?ui_svg_icon_x-circle.*?<span class="ui--span">Rename<\/span>/s,
		'heading carries the state icon and the title');
	like($html, qr/<p [^>]*\bui_dialog_desc\b[^>]*>Pick a name</, 'description under the heading');
	like($html, qr/<button (?=[^>]*\btype="button")(?=[^>]*\bui_dialog_x\b)(?=[^>]*\bdata-ui-dialog-close="1")(?=[^>]*\baria-label="Close")/,
		'closing cross');
	like($html, qr/<div [^>]*\bui_dialog_body\b[^>]*>\s*<input name="name">/,
		'body is inserted as given');
	like($html, qr/<footer [^>]*\bui_dialog_foot\b[^>]*>.*?<button type="submit">Go<\/button>.*?<button (?=[^>]*\bdata-ui-dialog-close="1")[^>]*>.*?Cancel/s,
		'footer holds the buttons, then the closing one');
	my $plain = main::ui_dialog({ 'title' => 'Plain', 'body' => 'x' });
	like($plain, qr/<dialog (?=[^>]*\bid="ui_dialog_\d+")(?=[^>]*\bui_dialog_normal\b)/,
		'id and size by default');
	unlike($plain, qr/<form|<footer|ui_dialog_danger/,
		'no form, footer or state unless asked');
	like($plain, qr/ui_dialog_title[^>]*><span class="ui--span">Plain</,
		'no heading icon unless asked');
	like(main::ui_dialog({ 'id' => 'u', 'form' => { 'method' => 'form-data', 'name' => 'up' } }),
		qr/<form (?=[^>]*\bmethod="post")(?=[^>]*\benctype="multipart\/form-data")(?=[^>]*\bname="up")/,
		'the form-data method makes an upload form');
	like(main::ui_dialog({ 'id' => 'c', 'close' => 1 }), qr/<footer.*?>Close</s,
		'close set to 1 uses the default label');
	like(main::ui_dialog({ 'id' => 'i', 'icon' => 'trash', 'state' => 'warning' }),
		qr/ui_svg_icon_trash/, 'an explicit icon replaces the state icon');
	unlike($plain, qr/aria-describedby/, 'no description, nothing to describe by');

	# The data forms : a form given as a URL, text before the body,
	# buttons given as hashes, and the focus on the closing button
	my $rich = main::ui_dialog({
		'id' => 'r', 'title' => 'Remove', 'desc' => 'Careful',
		'text' => 'Sure <b>?</b>', 'body' => '<i>more</i>',
		'form' => 'delete.cgi', 'width' => '30em',
		'buttons' => [
			{ 'label' => 'Remove', 'state' => 'danger', 'icon' => 'trash',
			  'name' => 'confirm', 'value' => 1 },
			{ 'label' => 'Later', 'close' => 1 },
			{ 'label' => 'Help', 'href' => 'help.cgi' },
			'<span class="raw">x</span>',
			],
		'close' => 'Cancel', 'focus' => 'close' });
	like($rich, qr/<form (?=[^>]*\baction="delete.cgi")(?=[^>]*\bmethod="post")/,
		'a form given as a URL posts to it');
	like($rich, qr/<dialog (?=[^>]*\baria-describedby="r_desc")(?=[^>]*\bstyle="--ui-dialog-width:30em")/,
		'the description is announced with the dialog and the width applied');
	like($rich, qr/<p (?=[^>]*\bid="r_desc")[^>]*>Careful</, 'the description carries its id');
	like($rich, qr/<p [^>]*\bui_dialog_text\b[^>]*>Sure &lt;b&gt;\?&lt;\/b&gt;<\/p>\s*<i>more<\/i>/,
		'text is escaped and comes before the body');
	like($rich, qr/<button (?=[^>]*\btype="submit")(?=[^>]*\bname="confirm")(?=[^>]*\bvalue="1")(?=[^>]*\bui_action_danger\b)[^>]*>.*?ui_svg_icon_trash.*?Remove/s,
		'a button in a form submits it with its name and value');
	like($rich, qr/<button (?=[^>]*\btype="button")(?=[^>]*\bdata-ui-dialog-close="1")[^>]*>.*?Later/s,
		'a closing button does not submit');
	like($rich, qr/<a (?=[^>]*\bhref="help.cgi")(?=[^>]*\bui_action\b)/, 'a button with a URL is a link');
	like($rich, qr/<span class="raw">x<\/span>/, 'raw strings are kept');
	like($rich, qr/<button (?=[^>]*\bdata-ui-dialog-close="1")(?=[^>]*\bautofocus\b)[^>]*>.*?Cancel/s,
		'the closing button takes the focus when asked');
	like($rich, qr/Remove.*Later.*help.cgi.*raw.*Cancel/s, 'buttons, footer and the closing button keep their order');
	unlike(main::ui_dialog({ 'id' => 'n', 'close' => 'OK' }), qr/autofocus/,
		'no autofocus unless asked');
	like(main::ui_dialog({ 'id' => 'b', 'buttons' => [ { 'label' => 'Go', 'autofocus' => 1 } ] }),
		qr/<button (?=[^>]*\btype="button")(?=[^>]*\bautofocus\b)/,
		'a button outside a form stays a plain button and can take the focus');
	assert_no_handler_injection(main::ui_dialog({ 'id' => 'x', 'text' => $xss,
		'width' => $xss, 'form' => $xss,
		'buttons' => [ { 'label' => $xss, 'href' => $xss, 'name' => $xss } ] }),
		'ui_dialog text and buttons');
	assert_no_handler_injection(main::ui_dialog({
		'id' => $xss, 'title' => $xss, 'desc' => $xss, 'close' => $xss,
		'form' => { 'action' => $xss, 'name' => $xss } }), 'ui_dialog text');
}

# Dialog buttons carry the dialog's id and the values to fill in
{
	my $html = main::ui_dialog_button('Rename', 'd1', 'info', {
		'values' => { 'name' => 'a "b"', 'file' => 'x' },
		'icon' => 'cursor-text', 'href' => 'ignored.cgi' });
	like($html, qr/<button (?=[^>]*\btype="button")(?=[^>]*\bdata-ui-dialog="d1")(?=[^>]*\bui_action_info\b)/,
		'a button opening its dialog, never a link');
	unlike($html, qr/href=/, 'the href option is dropped');
	my ($values) = $html =~ /data-ui-dialog-values="([^"]*)"/;
	is_deeply(main::convert_from_json(decode_attr($values)),
		{ 'name' => 'a "b"', 'file' => 'x' }, 'values survive attribute encoding');
	unlike(main::ui_dialog_button('Open', 'd2'), qr/data-ui-dialog-values/,
		'no values attribute without values');
	assert_no_handler_injection(main::ui_dialog_button($xss, $xss, 'info',
		{ 'values' => { $xss => $xss } }), 'ui_dialog_button text');
}

# Breadcrumbs : a list of links, the last one current
{
	my $html = main::ui_breadcrumb([
		{ 'icon' => 'home', 'href' => 'index.cgi?path=', 'title' => 'Root' },
		[ 'etc', 'index.cgi?path=%2Fetc' ],
		{ 'label' => 'webmin', 'icon' => 'folder' },
		], { 'id' => 'crumbs' });
	like($html, qr/<nav (?=[^>]*\bclass="[^"]*\bui_breadcrumb\b)(?=[^>]*\bid="crumbs")(?=[^>]*\baria-label="Breadcrumb")/,
		'nav with its label');
	like($html, qr/<li [^>]*\bui_breadcrumb_item\b[^>]*><a (?=[^>]*\bhref="index.cgi\?path=")(?=[^>]*\btitle="Root")(?=[^>]*\baria-label="Root")[^>]*>.*?ui_svg_icon_home/s,
		'an icon-only item is named by its title');
	like($html, qr/<a [^>]*\bhref="index.cgi\?path=%2Fetc"[^>]*><span class="ui--span">etc<\/span>/,
		'array items are label and link');
	like($html, qr/<li (?=[^>]*\bui_breadcrumb_current\b)(?=[^>]*\baria-current="page")[^>]*><span [^>]*>.*?ui_svg_icon_folder.*?<span class="ui--span">webmin<\/span>/s,
		'the last item is current, and plain text without a link');
	unlike($html, qr/<li [^>]*\bui_breadcrumb_current\b[^>]*><a /,
		'the current item is not a link when it has no URL');
	is(main::ui_breadcrumb([ ]), '', 'no items, no trail');
	assert_no_handler_injection(main::ui_breadcrumb([ [ $xss, $xss ],
		{ 'label' => $xss, 'title' => $xss } ], { 'label' => $xss }),
		'ui_breadcrumb text');
}

# Page links : arrows, the first and last pages and a window around the
# current one
{
	is(main::ui_pager({ 'page' => 1, 'pages' => 1, 'href' => 'x?page=' }), '',
		'one page needs no pager');
	my $html = main::ui_pager({ 'page' => 6, 'pages' => 12, 'href' => 'list.cgi?a=1&page=' });
	like($html, qr/<nav (?=[^>]*\bclass="[^"]*\bui_pager\b)(?=[^>]*\baria-label="Pages")/,
		'nav with its label');
	like($html, qr/<a (?=[^>]*\bui_pager_prev\b)(?=[^>]*\bhref="list.cgi\?a=1&amp;page=5")(?=[^>]*\baria-label="Previous page")/,
		'previous page link');
	like($html, qr/<a (?=[^>]*\bui_pager_next\b)(?=[^>]*\bhref="list.cgi\?a=1&amp;page=7")(?=[^>]*\baria-label="Next page")/,
		'next page link');
	like($html, qr/<span (?=[^>]*\bui_pager_current\b)(?=[^>]*\baria-current="page")[^>]*>6</,
		'the current page is marked, not linked');
	my @pages = $html =~ /ui_pager_link[^>]*>(\d+)</g;
	is_deeply(\@pages, [ 1, 4, 5, 6, 7, 8, 12 ],
		'first, last and the window around the current page');
	is(scalar(() = $html =~ /ui_pager_gap/g), 2, 'gaps on both sides');
	my $first = main::ui_pager({ 'page' => 1, 'pages' => 4, 'href' => 'p=' });
	like($first, qr/<span (?=[^>]*\bui_pager_prev\b)(?=[^>]*\bui_pager_disabled\b)(?=[^>]*\baria-disabled="true")/,
		'no previous page on the first');
	unlike($first, qr/ui_pager_gap/, 'no gaps when every page is shown');
	my @five = main::ui_pager({ 'page' => 1, 'pages' => 5, 'href' => 'p=' }) =~ /ui_pager_link[^>]*>(\d+)</g;
	is_deeply(\@five, [ 1, 2, 3, 4, 5 ], 'a single skipped page is shown instead of a gap');
	my @narrow = main::ui_pager({ 'page' => 50, 'pages' => 99, 'window' => 1, 'href' => 'p=' }) =~ /ui_pager_link[^>]*>(\d+)</g;
	is_deeply(\@narrow, [ 1, 49, 50, 51, 99 ], 'the window option narrows the range');
	like(main::ui_pager({ 'page' => 2, 'pages' => 3,
			      'url' => sub { "go.cgi?p=".$_[0]."&x=\"" } }),
		qr/href="go.cgi\?p=3&amp;x=&quot;"/, 'a url callback builds each link, escaped');
	assert_no_handler_injection(main::ui_pager({ 'page' => 2, 'pages' => 3,
		'href' => $xss, 'label' => $xss }), 'ui_pager text');
}

# ---- section titles, segmented controls and stacked fields -----------------

subtest 'section titles' => sub {
	my $html = main::ui_section_title('Recent', {
		'actions' => '<a href="clear.cgi">Clear list</a>', 'id' => 'recent' });
	like($html, qr/<div\b(?=[^>]*\bclass="[^"]*\bui_section_title\b)(?=[^>]*\bid="recent")[^>]*>/,
		'section title is a block carrying its id');
	like($html, qr/<h2 class="[^"]*\bui_section_title_text\b[^"]*">Recent<\/h2>/,
		'the title is a heading');
	like($html, qr/ui_section_title_actions"><a href="clear.cgi">Clear list<\/a>/,
		'actions are raw HTML at the right');
	unlike(main::ui_section_title('Plain'), qr/ui_section_title_actions/,
		'no actions block without actions');
	is(main::ui_section_title(undef), '', 'nothing without a title or actions');
	like(main::ui_section_title(undef, { 'title_html' => '<i>Raw</i>' }),
		qr/ui_section_title_text"><i>Raw<\/i>/, 'title_html is raw');
	assert_no_handler_injection(
		main::ui_section_title($xss, { 'class' => $xss, 'id' => $xss }),
		'ui_section_title');
};

subtest 'segmented controls' => sub {
	my $html = main::ui_segmented('mode', 1, [
		[ 0, 'Existing' ],
		{ 'value' => 1, 'label' => 'New', 'icon' => 'file-plus' },
		{ 'value' => 2, 'label' => 'Off', 'disabled' => 1, 'title' => 'Not now' },
		], { 'id' => 'mode_switch' });
	like($html, qr/<div\b(?=[^>]*\brole="radiogroup")(?=[^>]*\bid="mode_switch")[^>]*>/,
		'the control is a radio group with its id');
	my @inputs = $html =~ /(<input\b[^>]*>)/g;
	is(scalar(@inputs), 3, 'one input per option');
	like($inputs[0], qr/\btype="radio"/, 'options are radio inputs');
	like($inputs[0], qr/\bname="mode"/, 'radios share the field name');
	like($inputs[0], qr/\bvalue="0"/, 'array options keep their value');
	unlike($inputs[0], qr/\bchecked\b/, 'an unselected option is not checked');
	like($inputs[1], qr/\bchecked\b/, 'the matching value is checked');
	like($html, qr/ui_segment_label"><svg\b[^>]*\bui_svg_icon_file-plus\b/,
		'an option icon precedes its label');
	like($inputs[2], qr/\bdisabled\b/, 'a disabled option disables its radio');
	like($html, qr/<label\b(?=[^>]*\bui_segment_disabled\b)(?=[^>]*\btitle="Not now")[^>]*>/,
		'the disabled class and the tooltip sit on the label');
	like(main::ui_segmented('mode', 'missing', [ [ 'a', 'A' ], [ 'b', 'B' ] ]),
		qr/<input\b(?=[^>]*\bvalue="a")(?=[^>]*\bchecked\b)[^>]*>/,
		'an unknown value selects the first option');
	like(main::ui_segmented('mode', '', [ [ '', 'None' ], [ 'x', 'X' ] ]),
		qr/<input\b(?=[^>]*\bvalue="")(?=[^>]*\bchecked\b)[^>]*>/,
		'an empty value is submitted as empty');
	my $small = main::ui_segmented('mode', 0, [ [ 0, 'A' ], [ 1, 'B' ] ],
		{ 'size' => 'small', 'disabled' => 1, 'form' => 'f1' });
	like($small, qr/\bui_segmented_small\b/, 'the small size adds its class');
	my @small_inputs = $small =~ /(<input\b[^>]*>)/g;
	ok((grep { /\bdisabled\b/ && /\bform="f1"/ } @small_inputs) == 2,
		'whole-control disabling and the form id reach every radio');
	is(main::ui_segmented('mode', 0, []), '', 'no options yields nothing');
	is(main::ui_segmented('mode', 0, [ 'plain' ]), '',
		'options must be pairs or hashes');
	assert_no_handler_injection(main::ui_segmented($xss, $xss, [
		[ $xss, $xss ], { 'value' => 1, 'label' => $xss, 'title' => $xss } ],
		{ 'class' => $xss, 'id' => $xss, 'form' => $xss }), 'ui_segmented');
};

subtest 'stacked fields' => sub {
	my $html = main::ui_field('Path', '<input type="text" name="db" id="db">',
		{ 'for' => 'db', 'help' => 'Absolute <path>', 'id' => 'path_field' });
	like($html, qr/<div\b(?=[^>]*\bui_field\b)(?=[^>]*\bid="path_field")[^>]*>/,
		'the field is a block carrying its id');
	like($html, qr/<label\b(?=[^>]*\bui_field_label\b)(?=[^>]*\bfor="db")[^>]*>Path<\/label>/,
		'the label names its input');
	like($html, qr/ui_field_control"><input type="text" name="db" id="db"><\/div>/,
		'the control is raw HTML');
	like($html, qr/ui_field_help">Absolute &lt;path&gt;<\/div>/,
		'help text is escaped');
	like(main::ui_field('L', 'x', { 'help_html' => '<i>raw</i>' }),
		qr/ui_field_help"><i>raw<\/i>/, 'help_html is raw');
	my $bare = main::ui_field(undef, 'x');
	unlike($bare, qr/<label/, 'no label element without a label');
	unlike($bare, qr/ui_field_help/, 'no help block without help');
	like(main::ui_field(undef, 'x', { 'label_html' => '<b>L</b>' }),
		qr/ui_field_label"><b>L<\/b><\/label>/, 'label_html is raw');
	assert_no_handler_injection(main::ui_field($xss, 'x',
		{ 'for' => $xss, 'help' => $xss, 'class' => $xss, 'id' => $xss }),
		'ui_field');
};

# Navigation rows, icon tiles, the primary action and its trailing icon
{
	my $list = main::ui_list([
		{ 'title' => 'a.db', 'href' => 'open.cgi?db=a', 'icon' => 'database',
		  'chevron' => 1 },
		{ 'title' => 'b', 'chevron' => 1 } ], { 'icon_box' => 1 });
	like($list, qr/\bui_list_icon_box\b/, 'icon_box marks the list');
	my @chevrons = $list =~ /(<a\b[^>]*\bui_list_chevron\b[^>]*>)/g;
	is(scalar(@chevrons), 1, 'a chevron is only drawn for a row with a link');
	like($chevrons[0], qr/\baria-hidden="true"/,
		'the chevron is hidden from screen readers');
	like($chevrons[0], qr/\btabindex="-1"/, 'the chevron is not a tab stop');
	like($chevrons[0], qr/\bhref="open.cgi\?db=a"/,
		'the chevron repeats the row link');
	like($list, qr/\bui_svg_icon_database\b/, 'the database icon is drawn');
	unlike(main::ui_list([ { 'title' => 'a', 'href' => 'a.cgi' } ]),
		qr/ui_list_chevron|ui_list_icon_box|ui_list_stacked/,
		'rows without the options keep their markup');
	like(main::ui_list([ { 'title' => 'a', 'meta' => 'm', 'actions' => 'x' } ],
		{ 'stacked' => 1 }), qr/\bui_list_stacked\b/,
		'stacked puts the actions under the meta text');
	assert_no_handler_injection(main::ui_list([
		{ 'title' => 'a', 'href' => $xss, 'chevron' => 1 } ]),
		'ui_list chevron');

	my $primary = main::ui_action_button('Open', 'primary',
		{ 'icon' => 'arrow-right', 'icon_after' => 1 });
	like($primary, qr/\bui_action_primary\b/, 'primary is a state of its own');
	like($primary, qr/\bbtn-info\b/, 'primary uses the informational theme style');
	like($primary, qr/>Open<\/span>\s*<svg\b/,
		'icon_after puts the icon after the label');
	like(main::ui_action_button('Open', 'primary'),
		qr/ui_action_content"><span[^>]*>Open<\/span>\s*<\/span>/,
		'primary has no default icon');
	like(main::ui_action_button('Save', 'ok', { 'icon_after' => 1 }),
		qr/<svg\b[^>]*>.*<\/svg>\s*<span[^>]*>Save<\/span>|<span[^>]*>Save<\/span>\s*<svg\b/s,
		'icon_after also moves a state icon');
	like(main::ui_action_button('Save', 'ok', { 'icon_after' => 1 }),
		qr/<span[^>]*>Save<\/span>\s*<svg\b/,
		'and the state icon then follows the label');
	unlike(main::ui_badge('x', 'primary'), qr/ui_badge_primary/,
		'badges keep their own states');
}

done_testing();
