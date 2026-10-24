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

subtest 'local MySQL detection keeps loopback addresses remote' => sub {
	no warnings 'redefine';
	# A loopback address may be a tunnel or proxy to another host, so only
	# the socket, localhost and the system hostname's own address are local.
	# Debian can resolve the system hostname to 127.0.1.1, not 127.0.0.1.
	local *main::get_system_hostname = sub { 'db.example.test' };
	my %addresses = (
		'db.example.test' => '127.0.1.1',
		'local-alias.example.test' => '127.0.1.1',
		'remote.example.test' => '192.0.2.20',
		'::1' => undef,
		);
	local *main::to_ipaddress = sub {
		return exists($addresses{$_[0]}) ? $addresses{$_[0]} : $_[0];
		};
	for my $host ('', 'localhost', 'db.example.test', 'local-alias.example.test',
		     '127.0.1.1') {
		local $main::config{'host'} = $host;
		ok(main::is_mysql_local(), "$host is local");
		}
	for my $host ('127.0.0.1', '::1', '192.0.2.20', 'remote.example.test') {
		local $main::config{'host'} = $host;
		ok(!main::is_mysql_local(), "$host remains remote");
		}
};

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

subtest 'import directories are server-visible and unique' => sub {
	no warnings 'redefine';
	my $tmp = tempdir('webmin-mysql-staging-XXXXXX', DIR => '/tmp', CLEANUP => 1);
	my $data = "$tmp/data";
	my $secure = "$tmp/mysql-files";
	mkdir($data) or die $!;
	mkdir($secure) or die $!;
	my %vars = (datadir => "$data/", secure_file_priv => '');
	local @main::temporary_files;
	local *main::execute_sql_safe = sub {
		is_deeply([ @_ ], [ 'app_db',
			"show variables where Variable_name in ('secure_file_priv', 'datadir')" ],
			'ask the connected server for its permitted directories');
		return { data => [ map { [ $_, $vars{$_} ] } sort keys %vars ] };
		};
	my $first = main::mysql_import_tempdir('app_db');
	like($first, qr{^\Q$data\E/\#sql-webmin-import-[^/]+$},
		'use the server data directory, not the Webmin temp directory');
	is((stat($first))[2] & 0777, 0755, 'client and daemon can traverse the directory');
	is((stat($first))[4], $<, 'directory belongs to the creating Webmin process');
	my $second = main::mysql_import_tempdir('app_db');
	isnt($second, $first, 'simultaneous imports cannot reuse the same filename');
	$vars{'secure_file_priv'} = $secure;
	my $third = main::mysql_import_tempdir('app_db');
	like($third, qr{^\Q$secure\E/\#sql-webmin-import-[^/]+$},
		'prefer the configured server import directory');
	is_deeply(\@main::temporary_files, [ $first, $second, $third ],
		'register directories for cleanup even when an import fails');
	for my $disabled (undef, 'NULL') {
		$vars{'secure_file_priv'} = $disabled;
		like(main::mysql_import_tempdir('app_db'), qr{^\Q$data\E/},
			'NULL is not a path; leave server-side import restrictions to the server');
		}
	for my $invalid ("$tmp/missing", 'relative/path') {
		$vars{'secure_file_priv'} = $invalid;
		ok(!defined(main::mysql_import_tempdir('app_db')),
			'do not fall back outside a configured import directory');
		}
	%vars = ();
	ok(!defined(main::mysql_import_tempdir('app_db')),
		'missing server directories fail cleanly');

	# Only the import file location changes; retain the generated basename.
	local *main::tempname = sub { '/tmp/.webmin/'.($_[0] || 'generated.txt') };
	local *main::transname = sub {
		my $file = main::tempname(@_);
		push(@main::temporary_files, $file);
		return $file;
		};
	my @cleanup = @main::temporary_files;
	is(main::mysql_import_tempname($first, 'items.txt'), "$first/items.txt",
		'keep the table basename in the shared directory');
	is(main::mysql_import_tempname($first), "$first/generated.txt",
		'keep automatically generated basenames');
	is_deeply(\@main::temporary_files, \@cleanup,
		'do not register unused paths in the normal temp directory for deletion');
	is(main::mysql_import_tempname(undef, 'items.txt'), '/tmp/.webmin/items.txt',
		'remote and non-root imports keep their original temporary paths');
};

subtest 'server-side imports share the temporary file with the daemon group' => sub {
	no warnings 'redefine';
	my $tmp = tempdir('webmin-mysql-import-XXXXXX', DIR => '/tmp', CLEANUP => 1);
	my $file = "$tmp/items.txt";
	open(my $fh, '>', $file) or die $!;
	print $fh "1,fixture\n";
	close($fh) or die $!;
	my @uinfo = getpwuid($<);
	my $pidfile = "$tmp/mysqld.pid";
	my $pid = "1234\n";
	my %process = (args => '/usr/sbin/mariadbd', user => $uinfo[0],
		      _group => 'fixture-daemon-group');
	my $have_proc = 1;
	my ($result, @changes) = (1);
	local *main::execute_sql_safe = sub {
		is_deeply([ @_ ], [ 'app_db', "show variables like 'pid_file'" ],
			'ask the connected server for its PID file using an accessible database');
		return { data => [ [ 'pid_file', $pidfile ] ] };
		};
	local *main::read_file_contents = sub { return $pid };
	local *main::foreign_check = sub { return $have_proc };
	local *main::foreign_require = sub { };
	local *proc::process_info = sub {
		is($_[0], 1234, 'look up the server PID');
		return %process;
		};
	local *main::set_ownership_permissions = sub {
		push(@changes, [ @_ ]);
		return $result;
		};
	ok(main::set_mysql_import_file_permissions('app_db', $file),
		'prepare a server-side import');
	is_deeply(\@changes,
		[ [ (stat($file))[4], 'fixture-daemon-group', 0640, $file ] ],
		'keep the owner, grant the daemon group read, deny everyone else');
	# Some Unix process backends only expose the username.
	delete($process{'_group'});
	$process{'args'} = '/usr/sbin/mysqld --daemonize';
	ok(main::set_mysql_import_file_permissions('app_db', $file),
		'handle MySQL and a process backend without a group');
	is($changes[-1]->[1], $uinfo[3], 'fall back to the daemon account group');
	$result = 0;
	ok(!main::set_mysql_import_file_permissions('app_db', $file),
		'permission errors are reported');
	($result, @changes) = (1);
	for my $missing (undef, '', "invalid\n", "1234\n5678\n") {
		$pid = $missing;
		ok(main::set_mysql_import_file_permissions('app_db', $file),
			'leave permissions alone without a valid local PID');
		}
	$pid = "1234\n";
	$have_proc = 0;
	ok(main::set_mysql_import_file_permissions('app_db', $file),
		'leave permissions alone without the process module');
	$have_proc = 1;
	for my $args ('', '/usr/sbin/mysqld_safe', '/bin/sleep 1') {
		$process{'args'} = $args;
		ok(main::set_mysql_import_file_permissions('app_db', $file),
			'do not use a stale PID or a wrapper process');
		}
	is_deeply(\@changes, [], 'unidentified daemons do not change permissions');
	$process{'args'} = '/usr/sbin/mariadbd';
	ok(!main::set_mysql_import_file_permissions('app_db', "$tmp/missing.txt"),
		'a missing import file is reported');
	ok(!main::set_mysql_import_file_permissions('app_db', $tmp),
		'a directory is rejected');
	symlink($file, "$tmp/link.txt") or die $!;
	ok(!main::set_mysql_import_file_permissions('app_db', "$tmp/link.txt"),
		'a symlink is rejected');
	is_deeply(\@changes, [], 'invalid targets do not change permissions');
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
