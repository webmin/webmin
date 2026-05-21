#!/usr/bin/perl
# Unit tests for numeric / version-comparison helpers in web-lib-funcs.pl.
# Pure subs — bare require is enough.

use strict;
use warnings;
use Test::More;
use File::Basename qw(dirname);
use File::Spec;

my $script = File::Spec->rel2abs(
	File::Spec->catfile(dirname(__FILE__), '..', 'web-lib-funcs.pl'));
require $script;

# is_int — strict signed decimal integer.
#
# Regex is /^([-]?\d+)$/: allows a single leading "-", no leading "+",
# no whitespace, no scientific notation, no hex.
subtest 'is_int' => sub {
	ok( main::is_int('0'),    '"0" is int');
	ok( main::is_int('42'),   '"42" is int');
	ok( main::is_int('-5'),   'negative int');
	ok( main::is_int('01'),   'leading zero accepted');

	ok(!main::is_int('+5'),   'leading "+" rejected (no signed-positive form)');
	ok(!main::is_int(' 5'),   'leading whitespace rejected');
	ok(!main::is_int('5 '),   'trailing whitespace rejected');
	ok(!main::is_int('1.0'),  'decimals rejected');
	ok(!main::is_int('1e3'),  'scientific notation rejected');
	ok(!main::is_int('0x10'), 'hex rejected');
	ok(!main::is_int(''),     'empty rejected');
	ok(!main::is_int('abc'),  'non-numeric rejected');
	ok(!main::is_int(undef),  'undef rejected (no warnings under use warnings)');
};

# is_float — strict decimal with a dot.
#
# Regex is /^[-]?(\.\d+|\d+\.\d+)$/. The decimal point is required, so
# integers don't qualify. Trailing dot ("5.") is rejected. Scientific
# notation rejected.
subtest 'is_float' => sub {
	ok( main::is_float('1.5'),   'plain float');
	ok( main::is_float('-1.5'),  'negative float');
	ok( main::is_float('.5'),    'leading-dot form accepted');
	ok( main::is_float('-.5'),   'negative leading-dot form accepted');
	ok( main::is_float('0.0'),   'zero with decimal accepted');

	ok(!main::is_float('5'),     'plain integer rejected (decimal point required)');
	ok(!main::is_float('5.'),    'trailing-dot form rejected');
	ok(!main::is_float('1e3'),   'scientific notation rejected');
	ok(!main::is_float('+1.5'),  'leading "+" rejected');
	ok(!main::is_float(' 1.5'),  'leading whitespace rejected');
	ok(!main::is_float(''),      'empty rejected');
	ok(!main::is_float('abc'),   'non-numeric rejected');
	ok(!main::is_float(undef),   'undef rejected');
};

# float — parse-and-format helper.
#
# Returns sprintf('%.2f', $n) if that's non-zero, otherwise the literal 0.
# So unparseable input collapses to plain 0 (no decimals), but a valid
# zero number also returns plain 0 — the two are indistinguishable from
# the output side. Leading "+" is silently accepted here even though
# is_int / is_float reject it — asymmetric with the validators.
subtest 'float' => sub {
	is(main::float('42'),    '42.00',  'integer string → 2-decimal form');
	is(main::float('1.5'),   '1.50',   'float string → 2-decimal form');
	is(main::float('-1.5'),  '-1.50',  'negative float');
	is(main::float('1e3'),   '1000.00', 'scientific notation parsed');
	is(main::float('+5'),    '5.00',   'leading "+" silently accepted (asymmetric with is_int/is_float)');

	# All these collapse to plain 0 — non-parseable, empty, undef, true zero.
	is(main::float('abc'), 0, 'non-numeric → 0');
	is(main::float(''),    0, 'empty → 0');
	is(main::float(undef), 0, 'undef → 0');
	is(main::float('0'),   0, 'zero collapses to plain 0 (not "0.00")');
	is(main::float('0.0'), 0, 'zero with decimal also collapses to plain 0');
};

# compare_version_numbers — Debian-ish version comparator.
#
# Two calling shapes:
#   compare_version_numbers($a, $b)            → -1 / 0 / 1
#   compare_version_numbers($a, $op, $b)       → boolean
#
# Splits each version on /[.\-+~_]/, then walks segment-by-segment with
# a handful of special cases (pure numeric, numeric+string, "ubuntu"
# prefix strip, "rcN" < final).
subtest 'compare_version_numbers (numeric form)' => sub {
	# Equal.
	is(main::compare_version_numbers('1.0', '1.0'),     0, 'equal');
	is(main::compare_version_numbers('1.2.3', '1.2.3'), 0, 'equal three-part');

	# Numeric ordering — NOT lexical, so "1.10" > "1.9".
	is(main::compare_version_numbers('1.10', '1.9'),    1, '1.10 > 1.9 (numeric, not lexical)');
	is(main::compare_version_numbers('1.0', '1.1'),    -1, 'simple less-than');
	is(main::compare_version_numbers('2', '1.9'),       1, 'shorter higher major wins');

	# Different separators are interchangeable.
	is(main::compare_version_numbers('1-2', '1.2'),     0, 'dot and dash interchangeable');
	is(main::compare_version_numbers('1_2~3', '1.2.3'), 0, 'underscore and tilde interchangeable');

	# Numeric segment with a string tail — string compared after number.
	is(main::compare_version_numbers('1ubuntu5', '1ubuntu10'), -1, 'ubuntu5 < ubuntu10 (numeric tail)');
	is(main::compare_version_numbers('6redhat', '8redhat'),    -1, 'leading number wins over string tail');

	# Pure-string-prefix + number variant ("centos7" vs "centos8").
	is(main::compare_version_numbers('centos7', 'centos8'), -1, 'centos7 < centos8');

	# "ubuntu" prefix is silently stripped per-segment.
	is(main::compare_version_numbers('ubuntu5', '5'), 0,
	   '"ubuntu" prefix is stripped (ubuntu5 == 5)');

	# rcN is always older than the final release of the same number.
	is(main::compare_version_numbers('1rc1', '1'),   -1, 'rc1 < release');
	is(main::compare_version_numbers('1', '1rc1'),    1, 'release > rc1');
	is(main::compare_version_numbers('1RC1', '1'),   -1, 'rc match is case-insensitive');
	is(main::compare_version_numbers('1rc2', '1rc1'), 1, 'rc2 > rc1');

	# Other string tails (alpha, beta) are NOT special-cased like rc, so
	# they compare lexically after the leading number — and lose to a
	# bare number on the same prefix because "" sorts before "alpha".
	is(main::compare_version_numbers('1alpha', '1'),     1, '"alpha" tail > bare (lexical, no special-case)');
	is(main::compare_version_numbers('1beta', '1alpha'), 1, 'lexical compare of string tails');

	# Trailing-zero / segment-count asymmetry: 1.0 < 1.0.0 (the trailing
	# missing segment compares as "less than" 0). This is a quirk to be
	# aware of when normalizing version strings before compare.
	is(main::compare_version_numbers('1.0', '1.0.0'),   -1, 'shorter < longer when prefix matches');
	is(main::compare_version_numbers('1.0.0', '1.0'),    1, 'longer > shorter when prefix matches');

	# Empty / undef inputs degrade quietly to a numeric answer rather
	# than crashing.
	is(main::compare_version_numbers('', '1.0'),   -1, 'empty < non-empty');
	is(main::compare_version_numbers(undef, undef), 0, 'two undefs compare equal');
};

subtest 'compare_version_numbers (operator form)' => sub {
	ok( main::compare_version_numbers('1.0', '<',  '2.0'), '1.0 <  2.0');
	ok( main::compare_version_numbers('1.0', '<=', '1.0'), '1.0 <= 1.0');
	ok( main::compare_version_numbers('1.0', '==', '1.0'), '1.0 == 1.0');
	ok( main::compare_version_numbers('2.0', '>',  '1.0'), '2.0 >  1.0');
	ok( main::compare_version_numbers('2.0', '>=', '2.0'), '2.0 >= 2.0');

	ok(!main::compare_version_numbers('1.0', '>',  '2.0'), '1.0 not >  2.0');
	ok(!main::compare_version_numbers('1.0', '==', '2.0'), '1.0 not == 2.0');

	# Numeric-not-lexical also holds through the operator form.
	ok( main::compare_version_numbers('1.10', '>', '1.9'), '1.10 > 1.9 via op');
};

done_testing();
