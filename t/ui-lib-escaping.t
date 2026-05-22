#!/usr/bin/perl
# Tests for ui-lib.pl attribute escaping and XSS resistance.
#
# These cover the *default* (non-theme) code path. Each function checks for
# a theme override first and returns early if one is defined; when ui-lib.pl
# is loaded as a library, no theme is present, so the default path runs.
#
# The core invariant: caller-supplied data interpolated into HTML must not
# escape its attribute context. We check this by stripping all quoted
# attribute values from the output and asserting that no event-handler
# attribute (on*=) survives. If the input broke out of an attribute, the
# handler appears outside any quoted region and the assertion fails.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $root = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..'));
require File::Spec->catfile($root, 'web-lib-funcs.pl');
require File::Spec->catfile($root, 'ui-lib.pl');

# Strip all "..." and '...' quoted regions from $html so that what remains
# is tag scaffolding only. Any attribute introduced by an attribute-quote
# breakout will appear in the stripped output.
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
		"$label: no event-handler attribute leaks out of attribute value");
}

# Attribute-breakout payloads. The first is for double-quoted attrs, the
# second for single-quoted; we use whichever matches what the function
# emits (or both, when uncertain).
my $xss_dq = q{x"onmouseover="alert(1)};
my $xss_sq = q{x' onmouseover='alert(1)};

# ---- safe-contract regression tests ---------------------------------------
# These functions already escape correctly today. The tests lock that down.

assert_no_handler_injection(main::ui_textbox('field', $xss_dq, 20),
	'ui_textbox value');
assert_no_handler_injection(main::ui_textbox($xss_dq, 'safe', 20),
	'ui_textbox name');

# ui_textarea must escape < so a value cannot inject </textarea>.
{
	my $payload = q{</textarea><script>alert(1)</script>};
	my $html = main::ui_textarea('field', $payload, 5, 40);
	unlike($html, qr{</textarea><script}i,
		'ui_textarea value cannot close the textarea');
	like($html, qr{&lt;/textarea}, 'ui_textarea value html-escapes <');
}

assert_no_handler_injection(main::ui_hidden($xss_dq, $xss_dq),
	'ui_hidden name+value');
assert_no_handler_injection(
	main::ui_select('field', '', [[$xss_dq, 'label']]),
	'ui_select option value');
assert_no_handler_injection(main::ui_select($xss_dq, '', [['v','label']]),
	'ui_select name');
assert_no_handler_injection(main::ui_checkbox($xss_dq, 'v', 'label', 0),
	'ui_checkbox name');
assert_no_handler_injection(main::ui_oneradio($xss_dq, 'v', 'label', 0),
	'ui_oneradio name');
assert_no_handler_injection(main::ui_password('field', $xss_dq, 20),
	'ui_password value');
assert_no_handler_injection(main::ui_submit($xss_dq),
	'ui_submit label');
assert_no_handler_injection(main::ui_button($xss_dq),
	'ui_button label');

# ui_tag_start --- attribute values go through quote_escape.
assert_no_handler_injection(
	main::ui_tag_start('div', { 'data-foo' => $xss_dq }),
	'ui_tag_start data attribute');

# ---- the three XSS sites we are about to fix ------------------------------

# ui_help: title goes into aria-label="...". Single-quote breakout doesn't
# apply (attr is double-quoted), but double-quote breakout does.
assert_no_handler_injection(main::ui_help($xss_dq),
	'ui_help title');

# ui_img: src/alt/title all in single-quoted attrs today.
assert_no_handler_injection(main::ui_img('img.png', $xss_sq),
	'ui_img alt');
assert_no_handler_injection(main::ui_img('img.png', 'safe', $xss_sq),
	'ui_img title');
assert_no_handler_injection(
	main::ui_img(q{img.png' onerror='alert(1)}, 'safe'),
	'ui_img src');

# js_redirect: url must not be able to close the script tag, and the
# timeout/window parameters must not allow JS injection.
{
	# A literal </script> in script data closes the script element.
	# An extra <script> in script data is just text — the parser is
	# already in script-data state and only </script> exits it. So we
	# only assert on the close-tag count.
	my $url = q{/foo</script><script>alert(1)//};
	my $html = main::js_redirect($url);
	my $closes = () = $html =~ m{</script>}gi;
	is($closes, 1, 'js_redirect: url cannot inject </script>');
}
{
	# <!-- transitions the parser into script-data-escaped state, where
	# a subsequent <script>...</script> pair can hide the real closing
	# tag. The URL escape must neutralise this too.
	my $url = q{/foo<!--<script>alert(1)</script>-->};
	my $html = main::js_redirect($url);
	my $closes = () = $html =~ m{</script>}gi;
	is($closes, 1, 'js_redirect: url cannot inject <!-- script-data-escape');
}
{
	my $html = main::js_redirect('/x', undef, q{0);alert(1);//});
	unlike($html, qr/alert\(1\)/,
		'js_redirect: timeout coerced, no JS injection');
}
{
	my $html = main::js_redirect('/x', q{window;alert(1);//});
	unlike($html, qr/alert\(1\)/,
		'js_redirect: window validated, no JS injection');
}

done_testing();
