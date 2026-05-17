#!/usr/bin/perl
# Tests for web-lib-funcs.pl filter_javascript.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

is(
	main::filter_javascript('<video/onloadstart=alert(1) src=1>'),
	'<video/xonloadstart=alert(1) src=1>',
	'slash-separated HTML5 event handler is disabled',
);

is(
	main::filter_javascript('<img src=x onload=alert(1)>'),
	'<img src=x xonload=alert(1)>',
	'classic event handler is disabled',
);

is(
	main::filter_javascript('<div onwheel = alert(1) onpointerdown=alert(2)>'),
	'<div xonwheel = alert(1) xonpointerdown=alert(2)>',
	'multiple modern event handlers are disabled',
);

is(
	main::filter_javascript(
		'<a data-onload="safe" href="javascript:alert(1)">link</a>'),
	'<a data-onload="safe" href="xjavascript:alert(1)">link</a>',
	'non-handler attributes are preserved while script URIs are disabled',
);

done_testing();
