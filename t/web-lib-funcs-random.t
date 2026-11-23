#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use Errno qw(EINTR EIO);

our ($read_mode, $read_calls, $forbid_rand);
BEGIN {
	# Intercept only random reads made by the library loaded below.
	*CORE::GLOBAL::sysread = sub {
		return &fake_random_read(@_) if ($read_mode);
		return CORE::sysread($_[0], $_[1], $_[2], $_[3] || 0);
		};
	*CORE::GLOBAL::rand = sub (;$) {
		die "Secure mode called rand\n" if ($forbid_rand);
		return CORE::rand(@_ ? $_[0] : 1);
		};
	}
require "$FindBin::Bin/../web-lib-funcs.pl";

# fake_random_read(handle, buffer, length, [offset])
# Simulate source failures and partial reads without changing the host RNG.
sub fake_random_read
{
$read_calls++;
if ($read_mode eq 'error' ||
    ($read_mode eq 'partial-error' && $read_calls > 1)) {
	$! = EIO;
	return undef;
	}
if ($read_mode eq 'interrupt' && $read_calls == 1) {
	$! = EINTR;
	return undef;
	}
return 0 if ($read_mode eq 'eof' ||
	     ($read_mode eq 'partial-eof' && $read_calls > 1));
my $short = $read_mode eq 'short' || $read_mode =~ /^partial-/;
my $count = $short && $_[2] > 3 ? 3 : $_[2];
substr($_[1], $_[3] || 0) = 'x' x $count;
return $count;
}

subtest 'OS random bytes and errors' => sub {
	for my $length (0, 1, 24, 256) {
		my $bytes = main::secure_random_bytes($length);
		is(defined($bytes) ? length($bytes) : undef, $length,
			"real source supplies $length bytes");
		}
	for my $length (undef, -1, 257, '2.5', '12x') {
		ok(!defined(main::secure_random_bytes($length)),
			'invalid byte count is rejected');
		}
	for my $mode (qw(error eof partial-error partial-eof)) {
		local ($read_mode, $read_calls) = ($mode, 0);
		my @result = main::secure_random_bytes(24);
		is_deeply(\@result, [ undef ], "$mode returns explicit undef");
		is($read_calls, $mode =~ /^partial-/ ? 2 : 1,
			"$mode stops at the failed read");
		}
	for my $mode (qw(short interrupt)) {
		local ($read_mode, $read_calls) = ($mode, 0);
		is(main::secure_random_bytes(24), 'x' x 24,
			"$mode reads complete the requested buffer");
		cmp_ok($read_calls, '>', 1, "$mode retries the read");
		}
	};

# Load separate packages as web-lib.pl does for modules.
subtest 'Independent Webmin packages use the random source' => sub {
	{
		package RandomCallerOne;
		do "$FindBin::Bin/../web-lib-funcs.pl" || die $@ || $!;
		}
	{
		package RandomCallerTwo;
		do "$FindBin::Bin/../web-lib-funcs.pl" || die $@ || $!;
		}
	for my $package (qw(RandomCallerOne RandomCallerTwo)) {
		no strict 'refs';
		my $bytes = &{$package.'::secure_random_bytes'}(16);
		is(defined($bytes) ? length($bytes) : undef, 16,
			"$package reads the real OS random source");
		like(&{$package.'::substitute_pattern'}('[A-Za-z0-9]{24}',
			{ crypt => 1 }), qr/\A[A-Za-z0-9]{24}\z/,
			"$package generates a complete secure pattern");
		}
	};

subtest 'Secure patterns use the OS and propagate failures' => sub {
	no warnings qw(once redefine);
	local $forbid_rand = 1;
	my $key = main::substitute_pattern('[A-Za-z0-9]{24}', { crypt => 1 });
	like($key, qr/\A[A-Za-z0-9]{24}\z/,
		'24-character key uses the secure source');
	isnt(main::substitute_pattern('[A-Za-z0-9]{24}', { crypt => 1 }),
		$key, 'separate calls produce different keys');
	ok(!defined(main::substitute_pattern('[a-z]{24}',
		{ crypt => 1, 'no-shuffle' => 1 })),
		'secure mode rejects disabled shuffling');
	for my $bytes (undef, '', 'x' x 255) {
		local *main::secure_random_bytes = sub { return $bytes; };
		my @result = main::substitute_pattern('[a-z]{24}',
			{ crypt => 1 });
		is_deeply(\@result, [ undef ],
			'source failure cannot produce a key');
		}
	my ($calls, $callbacks) = (0, 0);
	local *main::secure_random_bytes = sub {
		return ++$calls == 1 ? "\0" x 256 : undef;
		};
	ok(!defined(main::substitute_pattern('[a-z]{200}',
		{ crypt => 1,
		  callback => sub { $callbacks++; return $_[0]; } })),
		'failure after a buffer refill does not return a partial key');
	is($callbacks, 0, 'failure does not invoke a success callback');
	};

subtest 'Secure selection rejects biased values' => sub {
	no warnings qw(once redefine);
	local $forbid_rand = 1;
	local *main::secure_random_bytes = sub {
		return pack('N*', 0xffffffff, 1, (0) x 62);
		};
	is(main::substitute_pattern('[0-2]{3}', { crypt => 1 }), '201',
		'rejects the excess value before reducing modulo three');
	};

subtest 'Existing caller patterns retain their behavior' => sub {
	no warnings qw(once redefine);
	local *main::secure_random_bytes = sub {
		die "Unexpected secure read\n";
		};
	for my $length (6, 20, 32, 40, 48) {
		like(main::substitute_pattern("[a-f0-9]{$length}"),
			qr/\A[a-f0-9]{$length}\z/,
			"existing hex pattern of length $length works");
		}
	is(main::substitute_pattern('[a-c]{3}', { 'no-shuffle' => 1 }),
		'abc', 'legacy no-shuffle output is unchanged');
	like(main::substitute_pattern('u-[0-9]{4}',
		{ filter => '[^A-Za-z0-9\\-_]', 'substitute-datetime' => 1 }),
		qr/\Au-[0-9]{4}\z/, 'Virtualmin username and filter work');
	is(main::substitute_pattern('[a-c]{3}',
		{ 'no-shuffle' => 1, callback => sub { uc($_[0]) } }),
		'ABC', 'existing callbacks retain their result');
	};

done_testing();
