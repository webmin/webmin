#!/usr/bin/perl
# Check the exported HTML helper with formatting and untrusted markup.
use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use WebminCore;

my @cases = (
	[ undef, '', 'undefined input is empty' ],
	[ '0', '0', 'zero is preserved' ],
	[ q{O'Reilly & Partners}, 'O&#39;Reilly &amp; Partners',
	  'plain text is escaped' ],
	[ 'café &amp; &lt;example&gt;', 'café &amp; &lt;example&gt;',
	  'Unicode and existing entities are preserved' ],
	[ '&amp;lt;literal&amp;gt;', '&amp;lt;literal&amp;gt;',
	  'entities are not decoded' ],
	[ '<B class="x"><i>name</i></B>', '<b><i>name</i></b>',
	  'nested formatting is retained without attributes' ],
	[ '<tt title="a > b" onclick=alert(1)>name</tt>', '<tt>name</tt>',
	  'quoted greater-than signs do not end attributes early' ],
	[ q{<span title='a > b' style='color:red'>name</span>},
	  '<span>name</span>', 'single-quoted attributes are removed' ],
	[ '<b/onmouseover=alert(1)>name</b>', '<b>name</b>',
	  'slash-separated attributes are removed' ],
	[ '<a href="java&#115;cript:alert(1)">name</a>', '<a>name</a>',
	  'encoded script URLs are removed with the attributes' ],
	[ '<p>one<br/>two</p><hr class=x>', '<p>one<br>two</p><hr>',
	  'paragraphs and void formatting tags are retained' ],
	[ '<table><tr><td colspan=2>name</td></tr></table>',
	  '<table><tr><td>name</td></tr></table>', 'table attributes are removed' ],
	[ '<ScRiPt>alert(1)</ScRiPt>', 'alert(1)',
	  'script tags are removed and their contents are inert text' ],
	[ '<style>body { color: red }</style>', 'body { color: red }',
	  'style tags cannot affect the page' ],
	[ '<iframe srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;">'.
	  'name</iframe>', 'name', 'embedded documents are removed' ],
	[ '<object data=x><embed src=x>name</object>', 'name',
	  'embedded objects are removed' ],
	[ '<svg><foreignObject><b>name</b></foreignObject></svg>',
	  '<b>name</b>', 'foreign elements are removed' ],
	[ '<math><mtext>name</mtext></math>', 'name',
	  'MathML elements are removed' ],
	[ '<custom-tag><b>name</b></custom-tag>', '<b>name</b>',
	  'custom elements are removed without losing ordinary formatting' ],
	[ '<!-- comment --><img src=x onerror=alert(1)>name', 'name',
	  'comments and image elements are removed' ],
	[ '<b title="unfinished', '&lt;b title&#61;&quot;unfinished',
	  'incomplete markup is escaped' ],
	[ '&#60;script&#62;alert(1)&#60;/script&#62;',
	  '&#60;script&#62;alert(1)&#60;/script&#62;',
	  'encoded markup stays text' ],
	);
foreach my $case (@cases) {
	is(html_sanitize($case->[0]), $case->[1], $case->[2]);
	}

# Caller-supplied tag lists can only narrow the built-in set.
is(html_sanitize('<b>B</b><i>I</i>', [ 'B' ]), '<b>B</b>I',
	'callers may select formatting tags case-insensitively');
is(html_sanitize('<b>B</b>', [ ]), 'B', 'an empty list removes all tags');
is(html_sanitize('<script>x</script><b>B</b>', [ 'script', 'b' ]),
	'x<b>B</b>', 'callers cannot enable script elements');

done_testing();
