#!/usr/bin/perl
# Tests for the generic tag builders in ui-lib.pl.
#
# Inline tags must close without a trailing newline, because browsers render
# that newline as a space between the tag and any punctuation that follows
# it. Block tags keep the newline for readable output, and void tags have no
# closing tag at all.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $root = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..'));
require File::Spec->catfile($root, 'web-lib-funcs.pl');
require File::Spec->catfile($root, 'ui-lib.pl');

# Tag classification is case-insensitive and tolerates a missing name.
ok(main::ui_tag_is_inline($_), "$_ is inline") for qw(tt b i em strong span
	a code kbd small sub sup u s q cite abbr var mark time TT Span);
ok(!main::ui_tag_is_inline($_), "$_ is not inline") for qw(div p ul li table
	td pre h1 label button select textarea svg img br DIV);
ok(!main::ui_tag_is_inline(undef), 'undefined tag is not inline');
ok(main::ui_tag_is_void($_), "$_ is void") for qw(br hr img input BR);
ok(!main::ui_tag_is_void($_), "$_ is not void") for qw(span div p a);
ok(!main::ui_tag_is_void(undef), 'undefined tag is not void');

# Closing tags follow the classification.
is(main::ui_tag_end('tt'), '</tt>', 'inline close has no newline');
is(main::ui_tag_end('span'), '</span>', 'span close has no newline');
is(main::ui_tag_end('div'), "</div>\n", 'block close keeps its newline');
is(main::ui_tag_end('ul'), "</ul>\n", 'list close keeps its newline');
is(main::ui_tag_end('label'), "</label>\n",
   'form labels keep the newline that separates them from controls');

# Complete tags combine the marker class with the right ending.
is(main::ui_tag('tt', 'guest'), '<tt class="ui--tt">guest</tt>',
   'inline tag renders without trailing whitespace');
is(main::ui_tag('tt', 'guest').'?', '<tt class="ui--tt">guest</tt>?',
   'punctuation after an inline tag stays attached');
is(main::ui_tag('div', 'x'), qq(<div class="ui--div">x</div>\n),
   'block tag ends with a newline');
is(main::ui_tag('br'), '<br class="ui--br">', 'void tag has no closing tag');
# Attribute order follows hash order, so match each attribute separately.
my $img = main::ui_tag('img', undef, { 'src' => 'a.png' });
like($img, qr{^<img\b[^>]*\bclass="ui--img"[^>]*>$}, 'void tag keeps its class');
like($img, qr{^<img\b[^>]*\bsrc="a\.png"[^>]*>$}, 'void tag keeps its attributes');
unlike($img, qr{</img>|\n}, 'void tag has neither closing tag nor newline');
is(main::ui_br(), '<br class="ui--br">', 'ui_br is a bare void tag');
like(main::ui_p('x'), qr{^<p class="ui--p">x</p>\n$}, 'ui_p is a block tag');
is(main::ui_tag('span', main::ui_tag('b', 'a').', '.main::ui_tag('b', 'b')),
   '<span class="ui--span"><b class="ui--b">a</b>, <b class="ui--b">b</b></span>',
   'nested inline tags form a tight comma list');

# Attribute values are still quote-escaped, with line breaks removed.
my $span = main::ui_tag('span', 'x', { 'title' => qq(a "b"\nc) });
like($span, qr{^<span\b[^>]*\btitle="a &quot;b&quot;c"[^>]*>x</span>$},
     'attribute escaping is unchanged for inline tags');

done_testing();
