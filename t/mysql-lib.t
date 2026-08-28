#!/usr/bin/perl
# Unit tests for MySQL module binary logging helpers.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use Cwd qw(abs_path);

BEGIN {
	# mysql-lib.pl imports WebminCore and initializes module globals at
	# load time. Stub only those load-time dependencies so its pure helpers
	# can be tested without a Webmin installation.
	$INC{'WebminCore.pm'} = 1;
	$INC{'view-lib.pl'} = 1;
	package WebminCore;
	sub import
	{
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::init_config'} = sub { };
	*{$caller.'::get_module_acl'} = sub { return (); };
	*{$caller.'::read_file_contents'} = sub { return "10.5.29-MariaDB\n"; };
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
	*{$caller.'::has_command'} = sub { return $_[0]; };
	*{$caller.'::quote_path'} = sub { return $_[0]; };
	*{$caller.'::backquote_command'} = sub { return ''; };
	}
}

my $root = abs_path(File::Spec->catdir(dirname(__FILE__), '..'));
chdir($root) or die "chdir($root): $!";
do './mysql/mysql-lib.pl' or die $@ || $!;

subtest 'binary log retention display round-trips exactly' => sub {
	# The page shows seconds as days, and saving converts the shown days
	# back with int(days * 86400 + 0.5), which must reproduce the exact
	# stored seconds even for non-round values
	foreach my $secs (0, 1, 43200, 86400, 100000, 123456789, 2592000,
			  4294967295) {
		my $days = main::format_binlog_expire_days($secs);
		like($days, qr/^\d+(\.\d+)?$/,
		     "$secs seconds display as plain decimal ($days)");
		is(int($days * 86400 + 0.5), $secs,
		   "$secs seconds round-trip through $days days");
		}
	is(main::format_binlog_expire_days(43200), '0.5',
	   'half a day is shown without trailing zeros');
	is(main::format_binlog_expire_days(2592000), '30',
	   'whole days are shown without a decimal point');
};

subtest 'default logging state considers variant, version and downtime' => sub {
	no warnings 'redefine';
	my $live;
	local *main::get_remote_mysql_variant = sub {
		return $live ? @$live : (-1);
		};

	$live = [ '8.0.36', 'mysql' ];
	ok(main::get_binlog_default_on(),
	   'a running MySQL 8 logs by default');
	$live = [ '5.7.44', 'mysql' ];
	ok(!main::get_binlog_default_on(),
	   'a running MySQL 5.7 does not log by default');
	$live = [ '10.11.6', 'mariadb' ];
	ok(!main::get_binlog_default_on(),
	   'a running MariaDB does not log by default');

	# When the server is stopped, the version cached at module setup
	# time must be used instead
	$live = undef;
	local $main::mysql_version = '8.0.36';
	ok(main::get_binlog_default_on(),
	   'a stopped MySQL 8 still counts as logging by default');
	is_deeply([ main::get_mysql_variant_cached() ],
		  [ '8.0.36', 'mysql' ],
		  'a stopped MySQL 8 falls back to the cached version');
	local $main::mysql_version = '10.5.29-MariaDB';
	ok(!main::get_binlog_default_on(),
	   'a stopped MariaDB does not count as logging by default');
	is_deeply([ main::get_mysql_variant_cached() ],
		  [ '10.5.29', 'mariadb' ],
		  'a stopped MariaDB falls back to the cached version');
};

subtest 'maximum log file size units and range' => sub {
	is(main::parse_binlog_max_size(100, 'M'), 104857600,
	   '100 MB converts to bytes');
	is(main::parse_binlog_max_size(4, 'K'), 4096,
	   'the 4 kB minimum is accepted');
	is(main::parse_binlog_max_size(1, 'G'), 1073741824,
	   'the 1 GB maximum is accepted');
	is(main::parse_binlog_max_size(8192, ''), 8192,
	   'plain bytes are accepted');
	ok(!defined(main::parse_binlog_max_size(1, 'K')),
	   'below the 4 kB minimum is rejected');
	ok(!defined(main::parse_binlog_max_size(2, 'G')),
	   'above the 1 GB maximum is rejected');
	ok(!defined(main::parse_binlog_max_size('abc', 'M')),
	   'a non-numeric size is rejected');
	ok(!defined(main::parse_binlog_max_size(100, 'T')),
	   'an unknown unit is rejected');
};

subtest 'rotation issues the expected statement' => sub {
	no warnings 'redefine';
	my @sql;
	local *main::execute_sql_logged = sub { push(@sql, [ @_ ]); };
	main::rotate_binary_logs();
	is_deeply(\@sql, [ [ 'mysql', 'flush binary logs' ] ],
		  'rotation runs FLUSH BINARY LOGS on the master database');
};

subtest 'binary log retention limit covers the full 32-bit range' => sub {
	# Saving validates the converted seconds against the variable's
	# 32-bit maximum, so the displayed maximum must be accepted while
	# anything above it is rejected
	my $maxdays = main::format_binlog_expire_days(4294967295);
	is($maxdays, '49710.269618', 'the 32-bit maximum displays in days');
	is(main::parse_binlog_expire_days($maxdays), 4294967295,
	   'the displayed maximum converts back within the limit');
	cmp_ok(main::parse_binlog_expire_days('49710.27'), '>', 4294967295,
	   'days just past the maximum exceed the seconds limit');
	cmp_ok(main::parse_binlog_expire_days(49710), '<=', 4294967295,
	   'whole days below the maximum stay within the limit');
};

done_testing();
