#!/usr/bin/perl
# Unit tests for Fail2Ban incremental-ban helpers.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

BEGIN {
	# fail2ban-lib.pl imports WebminCore and initializes module globals at
	# load time. Stub only those load-time dependencies so its pure helpers
	# can be tested without a Webmin installation.
	$INC{'WebminCore.pm'} = 1;
	package WebminCore;
	sub import
	{
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::init_config'} = sub { };
	*{$caller.'::get_module_acl'} = sub { return (); };
	*{$caller.'::compare_version_numbers'} = sub {
		my ($left, $right) = @_;
		my @left = split(/\./, $left);
		my @right = split(/\./, $right);
		my $count = @left > @right ? scalar(@left) : scalar(@right);
		for(my $i = 0; $i < $count; $i++) {
			my $cmp = ($left[$i] || 0) <=> ($right[$i] || 0);
			return $cmp if ($cmp);
			}
		return 0;
		};
	}
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";
do './fail2ban/fail2ban-lib.pl' or die $@ || $!;

subtest 'version support' => sub {
	ok(!main::supports_bantime_increment('0.10.6'), '0.10 is unsupported');
	ok(!main::supports_bantime_increment('0.11.0'), '0.11.0 is unsupported');
	ok(main::supports_bantime_increment('0.11.1'), '0.11.1 is supported');
	ok(main::supports_bantime_increment('0.11.2'), 'newer 0.11 is supported');
	ok(main::supports_bantime_increment('1.0.0'), '1.0 is supported');
};

subtest 'boolean canonicalization' => sub {
	is(main::canonical_fail2ban_boolean(undef), '', 'undefined stays unset');
	is(main::canonical_fail2ban_boolean('YES'), 'true', 'yes becomes true');
	is(main::canonical_fail2ban_boolean('on'), 'true', 'on becomes true');
	is(main::canonical_fail2ban_boolean('0'), 'false', 'zero becomes false');
	is(main::canonical_fail2ban_boolean('No'), 'false', 'no becomes false');
	is(main::canonical_fail2ban_boolean('invalid'), 'invalid',
	   'unknown values remain visible for correction');
};

subtest 'positive duration validation' => sub {
	foreach my $duration ('600', '30m', '1d 12h', '1d12h',
			     '2 weeks', '1month 2days', '0.5h') {
		ok(main::valid_positive_fail2ban_duration($duration),
		   "accepts $duration");
		}
	foreach my $duration ('', '0', '0m', '-1', '1d+12h',
			     '1d;system("id")', 'forever', '1m 2',
			     "1\nm", "1\r\nm") {
		ok(!main::valid_positive_fail2ban_duration($duration),
		   "rejects $duration");
		}
};

subtest 'non-negative duration validation' => sub {
	foreach my $duration ('0', '0m', '0 hours', '600', '30m', '1d 12h') {
		ok(main::valid_nonnegative_fail2ban_duration($duration),
		   "accepts $duration");
		}
	foreach my $duration ('', '-1', '1d+12h', 'forever') {
		ok(!main::valid_nonnegative_fail2ban_duration($duration),
		   "rejects $duration");
		}
};

subtest 'growth factor validation' => sub {
	foreach my $factor ('1', '2', '0.5', '.25', '24.0') {
		ok(main::valid_bantime_factor($factor), "accepts $factor");
		}
	foreach my $factor ('', '0', '-1', '1+1', 'inf', '1.') {
		ok(!main::valid_bantime_factor($factor), "rejects $factor");
		}
};

subtest 'form validation' => sub {
	my %valid = (
		'bantime_increment' => '',
		'bantime_factor_def' => 1,
		'bantime_maxtime_def' => 1,
		'bantime_overalljails' => '',
		'bantime_rndtime_def' => 1,
		);
	is(main::validate_bantime_increment_inputs(\%valid), undef,
	   'all-default input is valid');

	my %invalid = (%valid, 'bantime_increment' => 'maybe');
	is(main::validate_bantime_increment_inputs(\%invalid),
	   'jail_ebantime_increment', 'invalid enable value is identified');

	%invalid = (%valid, 'bantime_factor_def' => 0,
		'bantime_factor' => '2 * 3');
	is(main::validate_bantime_increment_inputs(\%invalid),
	   'jail_ebantime_factor', 'factor expressions are rejected');

	%invalid = (%valid, 'bantime_maxtime_def' => 0,
		'bantime_maxtime' => '0');
	is(main::validate_bantime_increment_inputs(\%invalid),
	   'jail_ebantime_maxtime', 'zero maximum time is rejected');

	my %zero_rndtime = (%valid, 'bantime_rndtime_def' => 0,
		'bantime_rndtime' => '0');
	is(main::validate_bantime_increment_inputs(\%zero_rndtime), undef,
	   'zero random time is accepted to disable inherited jitter');
};

subtest 'save mapping' => sub {
	my @saved;
	my $jail = { 'name' => 'sshd' };
	my %input = (
		'bantime_increment' => 'true',
		'bantime_factor_def' => 1,
		'bantime_maxtime_def' => 0,
		'bantime_maxtime' => '5w',
		'bantime_overalljails' => 'false',
		'bantime_rndtime_def' => 1,
		);
	{
	no warnings 'redefine';
	local *main::save_directive = sub {
		my ($name, $value, $section) = @_;
		push(@saved, [ $name, $value, $section ]);
		};
	main::save_bantime_increment_options(\%input, $jail);
	}
	is_deeply(
		[ map { [ $_->[0], $_->[1] ] } @saved ],
		[ [ 'bantime.increment', 'true' ],
		  [ 'bantime.factor', undef ],
		  [ 'bantime.maxtime', '5w' ],
		  [ 'bantime.overalljails', 'false' ],
		  [ 'bantime.rndtime', undef ] ],
		'form fields map through standard directive handling');
};

done_testing();
