#!/usr/bin/perl
# Unit tests for MySQL module helpers.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename qw(dirname);
use File::Spec;
use File::Temp qw(tempdir);
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

subtest 'database listings exclude raw dot directories and preserve valid names' => sub {
	no warnings 'redefine';
	my @hidden = ('#mysql50#.config', '#mysql50#.local', '#mysql50#.cache');
	my @names = ('zeta', @hidden, 'mysql', '#mysql50#legacy-name',
		     'App', '_config', '.config', '.local', '#reports');
	my @expected = ('#mysql50#legacy-name', '#reports', '.config', '.local',
			'_config', 'App', 'mysql', 'zeta');

	# Exercise the real mysqlshow output parser without a local database server.
	my $tmp = tempdir('webmin-mysql-list-XXXXXX', DIR => '/tmp', CLEANUP => 1);
	my $show = "$tmp/mysqlshow.pl";
	open(my $fh, '>', $show) or die "open($show): $!";
	my $edge = '+'.('-' x 24)."+\n";
	print $fh "print <<'TABLE';\n", $edge,
		sprintf("| %-22s |\n", 'Databases'), $edge,
		(map { sprintf("| %-22s |\n", $_) } @names), $edge,
		"TABLE\n";
	close($fh) or die "close($show): $!";
	local $main::config{'mysqlshow'} = $^X;
	local $main::authstr = quotemeta($show);

	# Both listing methods must remove invalid names and keep the same sorting.
	foreach my $source ('SQL', 'mysqlshow') {
		local *main::execute_sql_safe = sub {
			die "SQL unavailable\n" if ($source eq 'mysqlshow');
			return { 'data' => [ map { [ $_ ] } @names ] };
			};
		is_deeply([ main::list_databases() ], \@expected,
			  "$source excludes dot directories but keeps real database names");
		}

	# A successful SQL listing containing only invalid entries is simply empty.
	local *main::execute_sql_safe = sub {
		return { 'data' => [ map { [ $_ ] } @hidden ] };
		};
	is_deeply([ main::list_databases() ], [],
		  'filtering all SQL results does not trigger the command fallback');
};

subtest 'view definitions quote and parse special-character names' => sub {
	no warnings 'redefine';
	local *main::supports_quoting = sub { 1 };
	for my $name ('ordinary_view', q{view'&"<test>}, 'view with spaces',
		     'view`with`backticks', 'view ` as name') {
		my $quoted = $name;
		$quoted =~ s/`/``/g;
		$quoted = '`'.$quoted.'`';
		my $query = 'select 1 AS `value`';
		local *main::execute_sql = sub {
			is_deeply([ @_ ], [ 'app_db', 'show create view '.$quoted ],
				  'the full view name is a quoted SQL identifier');
			return { data => [ [ $name,
				'CREATE ALGORITHM=MERGE DEFINER=`root`@`localhost` '.
				'SQL SECURITY INVOKER VIEW '.$quoted.' AS '.$query.
				' WITH LOCAL CHECK OPTION' ] ] };
			};
		is_deeply(main::view_structure('app_db', $name), {
			name => $name, query => $query, algorithm => 'merge',
			definer => 'root@localhost', security => 'invoker', check => 'local'
			}, 'the edit form receives the original name and complete definition');
		}
};

subtest 'sandboxed SQL files use direct input' => sub {
	no warnings 'redefine';
	my $tmp = tempdir('webmin-mysql-sandbox-XXXXXX',
			  DIR => '/tmp', CLEANUP => 1);
	my $sqlfile = "$tmp/restore input.sql";
	open(my $fh, '>', $sqlfile) or die "open($sqlfile): $!";
	print $fh "select 1;\n";
	close($fh) or die "close($sqlfile): $!";

	my ($help_command, $sql_command);
	local $main::config{'mysql'} = '/opt/Maria DB/bin/mariadb';
	local $main::disable_session_binlog = 1;
	local $main::sql_charset;
	local *main::quote_path = sub { return "'".$_[0]."'"; };
	local *main::backquote_command = sub {
		$help_command = $_[0];
		return "  --sandbox  Enable sandbox mode\n";
		};
	ok(main::supports_sandbox_flag(), 'sandbox support is detected');
	is($help_command,
	   "'/opt/Maria DB/bin/mariadb' --help 2>&1 </dev/null",
	   'sandbox probe quotes the client path');

	local *main::is_readonly_mode = sub { return 0; };
	local *main::make_authstr = sub { return ''; };
	local *main::fix_collation = sub { return $_[0]; };
	local *main::supports_sandbox_flag = sub { return 1; };
	local *main::transname = sub {
		die "sandbox mode must not create a source wrapper";
		};
	local *main::set_authstr_env = sub { };
	local *main::backquote_logged = sub {
		$sql_command = $_[0];
		$? = 0;
		return '';
		};
	my ($status, $output) = main::execute_sql_file('mysql', $sqlfile);
	is($status, 0, 'sandboxed SQL execution succeeds');
	is($output, '', 'sandboxed SQL execution has no error output');
	like($sql_command, qr/^'\/opt\/Maria DB\/bin\/mariadb' /,
	     'SQL execution quotes the client path');
	like($sql_command, qr/ --sandbox /,
	     'SQL execution enables sandbox mode');
	like($sql_command,
	     qr/ --init-command='set session sql_log_bin = 0' /,
	     'binary-log suppression uses an initial SQL command');
	like($sql_command, qr/ <\Q@{[quotemeta($sqlfile)]}\E 2>&1\z/,
	     'the SQL file is connected directly to standard input');
	unlike($sql_command, qr/\bsource\b/,
	       'the sandboxed command does not use source');
};

subtest 'backup commands honor the backup user privilege boundary' => sub {
	local %main::module_info;
	local %main::access = ( 'buser' => 'root' );
	ok(!main::can_run_backup_commands(0),
	   'root commands require existing cron eligibility');
	ok(main::can_run_backup_commands(1),
	   'cron-eligible users can run root commands');

	$main::access{'buser'} = 'backupuser';
	ok(main::can_run_backup_commands(0),
	   'Webmin backups can run commands as a non-root backup user');
	$main::module_info{'usermin'} = 1;
	ok(!main::can_run_backup_commands(1),
	   'Usermin cannot gain backup command access');
};

subtest 'backup commands run as the non-root backup user' => sub {
	no warnings 'redefine';
	local $main::config{'backup_before_testdb'} = 'before-command';
	local $main::config{'backup_after_testdb'} = 'after-command';
	my @commands;
	local *main::command_as_user = sub {
		my ($user, $background, $command) = @_;
		is($background, 0, 'backup command remains synchronous');
		return "as-$user $command";
		};
	local *main::execute_command = sub {
		push(@commands, $_[0]);
		return 0;
		};

	ok(main::execute_before('testdb', undef, 0, '/tmp/test.sql',
				'testdb', 'backupuser'),
	   'before command succeeds');
	ok(main::execute_after('testdb', undef, 0, '/tmp/test.sql',
			       'testdb', 'backupuser'),
	   'after command succeeds');
	is_deeply(\@commands,
		  [ 'as-backupuser before-command',
		    'as-backupuser after-command' ],
		  'both commands are wrapped for the backup user');
	is($ENV{'BACKUP_FILE'}, '/tmp/test.sql',
	   'backup commands receive the destination path');
};

subtest 'database backup arguments preserve option boundaries' => sub {
	no warnings 'redefine';
	# Stub dump-client capabilities and capture the generated shell command.
	my $tmp = tempdir('webmin-mysql-backup-XXXXXX',
			  DIR => '/tmp', CLEANUP => 1);
	my $file = "$tmp/backup.sql";
	my ($writer_command, $logged_command);
	local $main::config{'mysqldump'} = '/usr/bin/mysqldump';
	local $main::authstr = '';
	local *main::supports_quoting = sub { return 0; };
	local *main::supports_routines = sub { return 0; };
	local *main::supports_mysqldump_events = sub { return 1; };
	local *main::supports_mysqldump_setgtid = sub { return 0; };
	local *main::set_authstr_env = sub { };
	local *main::shell_is_bash = sub { return 1; };
	# Capture the writer before the backup user wrapper is applied.
	local *main::command_as_user = sub {
		my ($user, $background, $command) = @_;
		is($user, 'backupuser', 'the configured backup user is used');
		is($background, 0, 'the backup remains synchronous');
		$writer_command = $command;
		return 'wrapped-writer-command';
		};
	# Simulate a successful dump while retaining its complete command.
	local *main::backquote_logged = sub {
		$logged_command = $_[0];
		open(my $fh, '>', $file) or die "open($file): $!";
		print $fh "dump\n";
		close($fh) or die "close($file): $!";
		$? = 0;
		return '';
		};

	# Use option-shaped values to verify each argument boundary.
	my $parameter = '--skip-comments';
	my $table = '--result-file=/root/forged-table';
	my $compatible = 'ansi --result-file=/root/forged-option; false';
	my $error = main::backup_database('testdb', $file, 0, 0, undef,
		undef, [ $compatible ], [ $table ], 'backupuser',
		0, 0, 0, $parameter);
	ok(!defined($error), 'the backup succeeds');
	like($logged_command, qr/\Q@{[quotemeta($parameter)]}\E .* -- testdb \Q@{[quotemeta($table)]}\E \|/,
	     'database and table names follow the end-of-options marker');
	like($logged_command, qr/ --events .* -- testdb /,
	     'generated dump options precede the end-of-options marker');
	like($logged_command, qr/ --compatible=\Q@{[quotemeta($compatible)]}\E /,
	     'the complete compatibility value is a single shell argument');
	is($writer_command, 'cat >'.quotemeta($file),
	   'only the output writer changes user, preserving database authentication');
};

subtest 'backup CGI enforces restrictions before saving or running' => sub {
	no warnings 'redefine';
	# Stub external Webmin services while running the real validation code.
	local $INC{'./mysql-lib.pl'} = 1;
	local %main::text = map { $_ => $_ } qw(backup_epath backup_eunder
		backup_eparameters backup_esave);
	local *main::ReadParse = sub { };
	local *main::error_setup = sub { };
	local *main::error = sub { die "$_[0]\n"; };
	local *main::text = sub { return $_[0]; };
	local *main::is_under_directory = sub {
		return $_[0] eq '/' || index($_[1], $_[0].'/') == 0;
		};
	local *main::foreign_installed = sub { return 1; };
	local *main::save_module_config = sub { die "SAVED\n"; };
	local *main::ui_print_header = sub { die "VALIDATED\n"; };
	local *main::list_databases = sub { return ('testdb'); };

	# Test each restriction independently and in representative combinations.
	foreach my $case (
		[ 'saved destination outside allowed path', 'nobody', '/allowed',
		  { save => 1, file => '/outside/dump' }, 'backup_epath' ],
		[ 'restricted user saves shared hook', 'nobody', '/allowed',
		  { save => 1, before => 'id' }, 'backup_esave' ],
		[ 'restricted user schedules shared hook', 'nobody', '/allowed',
		  { sched => 1, after => 'id' }, 'backup_esave' ],
		[ 'restricted user saves all-database settings', 'nobody', '/',
		  { save => 1, all => 1, before => 'id' }, 'backup_esave' ],
		[ 'parameter with restricted output path', 'root', '/allowed',
		  { parameters => '--result-file=/outside/dump' }, 'backup_eparameters' ],
		[ 'restricted user parameter', 'nobody', '/',
		  { parameters => '-r/outside/dump' }, 'backup_eparameters' ],
		[ 'valid confined backup', 'nobody', '/allowed',
		  { before => 'id' }, 'VALIDATED' ],
		[ 'valid root backup without cron access', 'root', '/',
		  {}, 'VALIDATED' ],
		) {
		my ($name, $user, $path, $input, $expected) = @$case;
		local %main::module_info;
		local %main::config;
		local %main::access = ( dbs => 'testdb', buser => $user,
			bpath => $path, user => 'dbuser' );
		local %main::in = ( db => 'testdb', file => '/allowed/backup.sql',
			where_def => 1, charset_def => 1, compatible_def => 1,
			tables_def => 1, %$input );
		local @main::tables;
		do './mysql/backup_db.cgi';
		like($@, qr/^\Q$expected\E\b/, $name);
		}
};

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

subtest 'retention maximum is variant specific' => sub {
	is(main::get_binlog_expire_max('mysql'), 4294967295,
	   'MySQL accepts the full 32-bit seconds range');
	is(main::get_binlog_expire_max('mariadb'), 8553600,
	   'MariaDB is limited to 99 days of seconds');
	is(main::parse_binlog_expire_days(99),
	   main::get_binlog_expire_max('mariadb'),
	   'exactly 99 days is accepted on MariaDB');
	cmp_ok(main::parse_binlog_expire_days('99.000012'), '>',
	   main::get_binlog_expire_max('mariadb'),
	   'just over 99 days exceeds the MariaDB limit');
	is(main::format_binlog_expire_days(8553600), '99',
	   'the MariaDB maximum displays as 99 days');
};

subtest 'preferred MySQL server configuration section' => sub {
	my $mariadb = { 'name' => 'mariadb' };
	my $mariadbd = { 'name' => 'mariadbd' };
	my $mysqld = { 'name' => 'mysqld' };
	my $client = { 'name' => 'client' };

	is(main::get_mysqld_config_section(
		[ $mariadb, $mariadbd, $mysqld ]), $mysqld,
	   'mysqld is preferred regardless of file order');
	is(main::get_mysqld_config_section([ $mariadb, $mariadbd ]), $mariadbd,
	   'mariadbd is preferred when mysqld is absent');
	is(main::get_mysqld_config_section([ $client, $mariadb ]), $mariadb,
	   'mariadb is used as the final server-section fallback');
	ok(!defined(main::get_mysqld_config_section([ $client ])),
	   'no server section returns undef');
};

done_testing();
