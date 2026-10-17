#!/usr/bin/perl
# Tests SQLite helpers, connection modes and SQL sandboxing.

use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin;

BEGIN { $ENV{'SQLITE_TESTING'} = 1; }
chdir "$FindBin::Bin/.." or die "chdir: $!";
require './sqlite-lib.pl';

our (%access, %config, %text, $remote_user);

# Build isolated allowed and denied directory trees for path checks.
my $root = tempdir(CLEANUP => 1);
my $allowed = "$root/allowed";
my $outside = "$root/outside";
make_path($allowed, $outside);
# Explicit ACL paths are canonical when saved by the access-control editor.
$allowed = simplify_path(resolve_links($allowed));
$outside = simplify_path(resolve_links($outside));
$access{'paths'} = $allowed;
$access{'create'} = 1;
$access{'write'} = 1;
$config{'busy_timeout'} = 100;
$config{'max_text'} = 8;
$text{'error_key'} = 'bad key';
$text{'value_more'} = '...';
$text{'value_more_chars'} = '+ $1 chars';
$text{'value_more_chars_truncated'} = '+ $1 of $2 chars';
$text{'value_blob'} = '[binary value, $1 bytes]';

# Check fail-closed ACL parsing and directory boundaries.
is_deeply([ sqlite_acl_paths(undef) ], [],
	'missing path ACL grants no database access');
my @current_user = getpwuid($<);
SKIP: {
	# A safe ACL can resolve $HOME only when the Webmin user exists in Unix.
	skip('current Unix account has no absolute home directory', 1)
		if (!$current_user[0] || !$current_user[7] ||
		    $current_user[7] !~ m!^/!);
	local $remote_user = $current_user[0];
	my $expected = simplify_path(resolve_links($current_user[7]));
	is_deeply([ sqlite_acl_paths('$HOME') ], [ $expected ],
		'safe path ACL expands the Unix user home directory');
	}
{
	# An unknown Webmin user must not inherit the Webmin process home.
	local $remote_user = 'sqlite-safe-user-that-does-not-exist';
	is_deeply([ sqlite_acl_paths('$HOME') ], [],
		'safe path ACL fails closed without a matching Unix user');
}
SKIP: {
	# With a named Unix user, $HOME is that user's home even when the
	# Webmin user has no account of its own.
	skip('current Unix account has no absolute home directory', 1)
		if (!$current_user[0] || !$current_user[7] ||
		    $current_user[7] !~ m!^/!);
	local $remote_user = 'sqlite-safe-user-that-does-not-exist';
	local $access{'work_as_root'} = 0;
	local $access{'work_as_user'} = $current_user[0];
	my $expected = simplify_path(resolve_links($current_user[7]));
	is_deeply([ sqlite_acl_paths('$HOME') ], [ $expected ],
		'safe path ACL follows the named Unix user home directory');
	}
my %safe_acl;
read_file('safeacl', \%safe_acl);
is_deeply(\%safe_acl, {
	'paths' => '$HOME',
	'write' => '1',
	'create' => '1',
	'sql' => '0',
	'work_as_root' => '0',
	'work_as_user' => '',
	}, 'safe ACL allows structured changes only in the user home, as the user');

# Check which Unix user the module does its file work as.
{
	local $remote_user = 'tester';
	is(sqlite_work_as_user({ 'work_as_root' => 1, 'paths' => '$HOME' }), undef,
		'an explicit root setting stays root');
	is(sqlite_work_as_user({ 'work_as_root' => 0, 'paths' => '/' }), 'tester',
		'an explicit same-user setting uses the Webmin user');
	is(sqlite_work_as_user({ 'work_as_root' => 0, 'work_as_user' => 'app',
		'paths' => '/' }), 'app', 'a named Unix user wins');
	is(sqlite_work_as_user({ 'paths' => '$HOME' }), 'tester',
		'an older home-only ACL implies the Webmin user');
	is(sqlite_work_as_user({ 'paths' => "/srv\t\$HOME" }), undef,
		'an older ACL with other directories stays root');
	is(sqlite_work_as_user({ 'paths' => '/' }), undef,
		'an older root ACL stays root');
	is(sqlite_work_as_user({ }), undef, 'an empty ACL stays root');
	# Once switched, the recent list moves into the user's home.
	our $sqlite_unix_home;
	local $sqlite_unix_home = '/home/tester';
	like(sqlite_recent_file(), qr{^/home/tester/\.webmin-sqlite/tester$},
		'a switched user keeps the recent list in the home directory');
}

ok(sqlite_path_under("$allowed/example.db", $allowed),
	'child path is allowed');
ok(!sqlite_path_under("$outside/example.db", $allowed),
	'neighbor path is rejected');
my $resolved_allowed = simplify_path(resolve_links($allowed));
is(sqlite_database_path("$allowed/new.db", 1), "$resolved_allowed/new.db",
	'new database path is accepted inside allowed directory');
is(sqlite_filename_uri('/tmp/a;b=c%20.db'),
	'file:/tmp/a%3Bb%3Dc%2520.db',
	'filename URI escapes DBD connection syntax and literal percent signs');

# A saved ACL root stays fixed even if its former directory is replaced by
# a symbolic link to an outside location.
SKIP: {
	my $replaceable = "$root/replaceable";
	make_path($replaceable);
	my $pinned = simplify_path(resolve_links($replaceable));
	rmdir($replaceable) or die "rmdir $replaceable: $!";
	skip('symbolic links are unavailable', 2)
		if (!symlink($outside, $replaceable));
	my $retargeted = simplify_path(resolve_links("$replaceable/private.db"));
	my ($root_acl) = sqlite_acl_paths($pinned);
	ok(!sqlite_path_under($retargeted, $root_acl),
		'root keeps a saved ACL directory fixed');
	my ($user_acl) = sqlite_acl_paths($pinned);
	is($user_acl, $pinned,
		'an unprivileged worker also keeps the ACL directory fixed');
	}

# Restricted path ACLs require SQLite's full-path no-follow protection.
ok(!sqlite_secure_open_available(3038999),
	'restricted access rejects SQLite before 3.39');
ok(sqlite_secure_open_available(3039000),
	'restricted access accepts SQLite 3.39');
# The root ACL has no narrower directory boundary to enforce.
{
	local $access{'paths'} = '/';
	ok(sqlite_secure_open_available(3030999),
		'an unrestricted ACL needs no directory boundary');
}

# Ownership changes must reject links instead of following them as root.
SKIP: {
	my $target = "$outside/chown-target";
	my $link = "$allowed/chown-link";
	open(my $fh, '>', $target) or die "open $target: $!";
	close($fh) or die "close $target: $!";
	skip('symbolic links are unavailable', 1) if (!symlink($target, $link));
	my @st = stat($target);
	ok(!sqlite_safe_chown($link, $st[4], $st[5]),
		'ownership helper refuses a symbolic link');
	}

# Check row identities with NULL, punctuation and Unicode values.
my @input = (1, undef, "a:b;c", "\x{263a}");
my $token = sqlite_encode_key(@input);
my @output = sqlite_decode_key($token, scalar(@input));
is_deeply(\@output, \@input, 'row identity round trips');

# Check long-text disclosure markup.
$config{'max_text'} = 1000;
my $short_value = sqlite_display_value('unbroken-text-value');
like($short_value, qr/overflow-wrap:anywhere;word-break:break-word/,
	'short text can shrink with its table column');
my $long_value = sqlite_display_value('x' x 140);
like($long_value, qr/<details class="inline inlined">/,
	'long text uses an inline details disclosure');
like($long_value, qr/<summary>\+ 12 chars<\/summary>/,
	'long text reports the number of hidden characters');
like($long_value, qr/^<span[^>]*>@{['x' x 128]} /,
	'long text leaves the first 128 characters visible');
like($long_value, qr/overflow-wrap:anywhere;word-break:break-word/,
	'long text can shrink with its table column');
unlike($long_value, qr/min-width:/,
	'long text does not force a minimum table width');
$config{'max_text'} = 8;
# Later helpers receive paths returned by sqlite_database_path, which are
# canonical even when a temporary-directory prefix is a symbolic link.
$allowed = $resolved_allowed;
$outside = simplify_path(resolve_links($outside));
$access{'paths'} = $allowed;

# Check the per-user recent list: the limit, ordering, de-duplication, ACL
# filtering, deleted files and clearing.
our $module_config_directory;
$module_config_directory = "$root/config";
make_path($module_config_directory);
$text{'index_today'} = 'Today, $1';
$text{'index_yesterday'} = 'Yesterday, $1';
# sub touch(path)
# Creates one empty fixture file.
sub touch
{
my ($path) = @_;
open(my $fh, '>', $path) or die "open $path: $!";
close($fh) or die "close $path: $!";
}
{
	local $remote_user = 'tester';
	is(sqlite_recent_limit(), 3, 'recent list keeps three entries by default');
	$config{'recent'} = 2;
	is(sqlite_recent_limit(), 2,
		'recent list limit comes from the module config');
	like(sqlite_recent_file(), qr{/recent/tester$},
		'recent list is stored per Webmin user');
	touch("$allowed/$_") foreach ('a.db', 'b.db', 'c.db');
	touch("$outside/d.db");
	sqlite_remember_recent("$allowed/a.db", 1);
	sqlite_remember_recent("$allowed/b.db", 2);
	is_deeply([ map { $_->{'path'} } sqlite_list_recent() ],
		[ "$allowed/b.db", "$allowed/a.db" ], 'recent list is newest first');
	sqlite_remember_recent("$allowed/a.db", 5);
	my @again = sqlite_list_recent();
	is_deeply([ map { $_->{'path'} } @again ],
		[ "$allowed/a.db", "$allowed/b.db" ],
		'reopening moves a database to the top without a duplicate');
	is($again[0]->{'tables'}, 5, 'reopening refreshes the table count');
	ok($again[0]->{'time'} > 0 && defined($again[0]->{'size'}),
		'entries carry the opening time and the file size');
	sqlite_remember_recent("$allowed/c.db", 0);
	is_deeply([ map { $_->{'path'} } sqlite_list_recent() ],
		[ "$allowed/c.db", "$allowed/a.db" ],
		'recent list keeps only the configured number of entries');
	$config{'recent'} = 3;
	sqlite_remember_recent("$outside/d.db", 0);
	ok(!(grep { $_->{'path'} eq "$outside/d.db" } sqlite_list_recent()),
		'databases outside the ACL are hidden from the recent list');
	unlink("$allowed/c.db");
	ok(!(grep { $_->{'path'} eq "$allowed/c.db" } sqlite_list_recent()),
		'deleted databases are hidden from the recent list');
	sqlite_forget_recent("$allowed/a.db");
	ok(!(grep { $_->{'path'} eq "$allowed/a.db" } sqlite_list_recent()),
		'forgetting one database removes only that entry');
	ok(-e sqlite_recent_file(),
		'the list file stays while other entries remain');
	sqlite_forget_recent();
	is_deeply([ sqlite_list_recent() ], [],
		'clearing the list removes every entry');
	ok(!-e sqlite_recent_file(), 'clearing the list removes the stored file');
	$config{'recent'} = 0;
	sqlite_remember_recent("$allowed/a.db", 1);
	is_deeply([ sqlite_list_recent() ], [],
		'a zero limit disables the recent list');
	ok(!-e sqlite_recent_file(), 'a zero limit records nothing');
	delete($config{'recent'});
}
{
	local $remote_user = '';
	is(sqlite_recent_file(), undef, 'no recent list without a logged-in user');
}
like(sqlite_recent_time(time()), qr/^Today, \d\d:\d\d$/,
	'a time from today shows the clock');
like(sqlite_recent_time(time() - 86400), qr/^Yesterday, \d\d:\d\d$/,
	'a time from yesterday says so');
my $older = sqlite_recent_time(time() - 7 * 86400);
ok(length($older) && $older !~ /^(Today|Yesterday)/,
	'older times show a date');
is(sqlite_recent_time(0), '', 'a missing time shows nothing');

# Check the statements built from the table form.
$text{'create_ename'} = "Invalid table name '\$1'";
$text{'create_ecolumns'} = 'No columns were entered';
$text{'create_ecolumn'} = "Invalid column name '\$1'";
$text{'create_edup'} = "Column '\$1' is listed more than once";
$text{'create_etype'} = "Invalid type for column '\$1'";
$text{'create_eauto'} = "Autoincrement requires '\$1' to be the only primary key column and have type INTEGER";
is(sqlite_default_literal('abc'), "'abc'", 'text defaults are quoted');
is(sqlite_default_literal("it's"), "'it''s'", 'quotes in defaults are doubled');
is(sqlite_default_literal('42'), '42', 'integer defaults stay numeric');
is(sqlite_default_literal('-1.5e3'), '-1.5e3', 'float defaults stay numeric');
is(sqlite_default_literal('null'), 'NULL', 'NULL default is the keyword');
is(sqlite_default_literal('current_timestamp'), 'CURRENT_TIMESTAMP',
	'time keywords are passed through');
is(sqlite_default_literal('1 or 2'), "'1 or 2'",
	'anything else is a string literal');
ok(sqlite_valid_name('users'), 'plain names are valid');
ok(sqlite_valid_name('odd "name'), 'names needing quotes are valid');
ok(!sqlite_valid_name(''), 'empty names are invalid');
ok(!sqlite_valid_name("a\nb"), 'names with control characters are invalid');
ok(!sqlite_valid_name('sqlite_master'), 'the sqlite_ namespace is reserved');
is_deeply([ sqlite_column_types() ],
	[ 'INTEGER', 'TEXT', 'REAL', 'BLOB', 'NUMERIC' ],
	'the form offers the five storage classes');
is(sqlite_create_table_sql('t', [
	{ 'name' => 'id', 'type' => 'INTEGER', 'null' => 0, 'key' => 'pkai' },
	{ 'name' => 'name', 'type' => 'TEXT', 'null' => 1, 'key' => '',
	  'default' => '' } ]),
	'CREATE TABLE "t" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" TEXT)',
	'a single integer key becomes the rowid alias');
is(sqlite_create_table_sql('t', [
	{ 'name' => 'code', 'type' => 'TEXT', 'null' => 1, 'key' => 'pk' },
	{ 'name' => 'email', 'type' => 'TEXT', 'null' => 0, 'key' => 'unique',
	  'default' => 'x' } ]),
	'CREATE TABLE "t" ("code" TEXT PRIMARY KEY NOT NULL, "email" TEXT NOT NULL UNIQUE DEFAULT \'x\')',
	'a text key is forced NOT NULL and unique columns take a default');
is(sqlite_create_table_sql('odd "t', [
	{ 'name' => 'a', 'type' => 'TEXT', 'null' => 1, 'key' => 'pk' },
	{ 'name' => 'b', 'type' => 'INTEGER', 'null' => 1, 'key' => 'pk' } ]),
	'CREATE TABLE "odd ""t" ("a" TEXT NOT NULL, "b" INTEGER NOT NULL, PRIMARY KEY ("a", "b"))',
	'several keys form a table-level composite key in a quoted table');
my $column = { 'name' => 'id', 'type' => 'INTEGER', 'null' => 1, 'key' => '' };
eval { sqlite_create_table_sql('sqlite_x', [ $column ]) };
like($@, qr/^Invalid table name 'sqlite_x'/, 'reserved table names are rejected');
eval { sqlite_create_table_sql('t', [ ]) };
like($@, qr/^No columns were entered/, 'a table needs a column');
eval { sqlite_create_table_sql('t', [ $column,
	{ 'name' => 'ID', 'type' => 'TEXT', 'null' => 1, 'key' => '' } ]) };
like($@, qr/^Column 'ID' is listed more than once/,
	'column names are unique without regard to case');
eval { sqlite_create_table_sql('t', [
	{ 'name' => 'x', 'type' => 'VARCHAR', 'null' => 1, 'key' => '' } ]) };
like($@, qr/^Invalid type for column 'x'/, 'only the offered types are accepted');
eval { sqlite_create_table_sql('t', [
	{ 'name' => 'x', 'type' => 'TEXT', 'null' => 1, 'key' => 'pkai' } ]) };
like($@, qr/^Autoincrement requires/, 'autoincrement needs an INTEGER column');
eval { sqlite_create_table_sql('t', [
	{ 'name' => 'x', 'type' => 'INTEGER', 'null' => 1, 'key' => 'pkai' },
	{ 'name' => 'y', 'type' => 'INTEGER', 'null' => 1, 'key' => 'pk' } ]) };
like($@, qr/^Autoincrement requires/, 'autoincrement needs a single key column');
eval { sqlite_create_table_sql('t', [
	{ 'name' => "a\tb", 'type' => 'TEXT', 'null' => 1, 'key' => '' } ]) };
like($@, qr/^Invalid column name/, 'column names are checked too');

# Check the version gate and the statements for adding a column.
ok(!sqlite_supports('rename_column', 3024000),
	'column renames need SQLite 3.25');
ok(sqlite_supports('rename_column', 3025000),
	'SQLite 3.25 can rename columns');
ok(!sqlite_supports('drop_column', 3034999),
	'column drops need SQLite 3.35');
ok(sqlite_supports('drop_column', 3035000),
	'SQLite 3.35 can drop columns');
ok(!sqlite_supports('alter_column', 3999000),
	'unknown features are never supported');
ok(!sqlite_supports('nofollow', 3038999),
	'full-path no-follow needs SQLite 3.39');
ok(sqlite_supports('nofollow', 3039000),
	'SQLite 3.39 refuses links in every path component');
# As a normal user the ownership helper changes nothing and never dies.
touch("$allowed/owned.db");
touch("$allowed/owned.db-wal");
my @before = stat("$allowed/owned.db-wal");
sqlite_adopt_ownership("$allowed/owned.db");
sqlite_adopt_ownership("$allowed/missing.db");
is_deeply([ (stat("$allowed/owned.db-wal"))[4, 5] ], [ @before[4, 5] ],
	'ownership adoption leaves files alone when not running as root');
$text{'column_enotnull'} = 'A column that does not allow NULL needs a default value for the existing rows';
$text{'column_ecurrent'} = 'An added column cannot default to the current time or date';
is(sqlite_add_column_sql('t', { 'name' => 'note', 'type' => 'TEXT',
	'null' => 1, 'default' => '' }),
	'ALTER TABLE "t" ADD COLUMN "note" TEXT',
	'an optional column needs no default');
is(sqlite_add_column_sql('t', { 'name' => 'count', 'type' => 'INTEGER',
	'null' => 0, 'default' => '0' }),
	'ALTER TABLE "t" ADD COLUMN "count" INTEGER NOT NULL DEFAULT 0',
	'a required column carries its default');
eval { sqlite_add_column_sql('t', { 'name' => 'count', 'type' => 'INTEGER',
	'null' => 0, 'default' => '' }) };
like($@, qr/^A column that does not allow NULL needs a default/,
	'a required column without a default is rejected');
eval { sqlite_add_column_sql('t', { 'name' => 'count', 'type' => 'INTEGER',
	'null' => 0, 'default' => 'null' }) };
like($@, qr/^A column that does not allow NULL needs a default/,
	'a NULL default does not satisfy NOT NULL');
eval { sqlite_add_column_sql('t', { 'name' => 'when', 'type' => 'TEXT',
	'null' => 1, 'default' => 'current_timestamp' }) };
like($@, qr/^An added column cannot default to the current time/,
	'time defaults are rejected for added columns');
eval { sqlite_add_column_sql('t', { 'name' => 'x', 'type' => 'JSON',
	'null' => 1, 'default' => '' }) };
like($@, qr/^Invalid type for column 'x'/, 'added columns take the offered types');
eval { sqlite_add_column_sql('t', { 'name' => 'sqlite_x', 'type' => 'TEXT',
	'null' => 1, 'default' => '' }) };
like($@, qr/^Invalid column name 'sqlite_x'/, 'added column names are checked');

# Run database-level checks only when the optional SQLite driver is installed.
SKIP: {
	my $driver_error = sqlite_load_driver();
	# Skip only database tests when DBD::SQLite is unavailable.
	skip("DBD::SQLite unavailable: $driver_error", 31) if ($driver_error);
	# Database helper tests use an unrestricted ACL so they can run with an
	# older local SQLite; restricted-path version gates are tested above.
	local $access{'paths'} = '/';
	# Create a writable fixture and test schema and query helpers.
	my $database = "$allowed/example.db";
	my $dbh = sqlite_connect($database, 1, 1);
	my ($foreign_keys) = $dbh->selectrow_array('PRAGMA foreign_keys');
	is($foreign_keys, 1, 'foreign-key enforcement is enabled');
	$dbh->do('CREATE TABLE sample (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, data BLOB)');
	$dbh->do('INSERT INTO sample (name, data) VALUES (?, ?)', undef,
		'first', "a\0b");
	my $objects = sqlite_objects($dbh);
	is(scalar(@$objects), 1, 'one table listed');
	is($objects->[0]->{'name'}, 'sample', 'table name listed');
	my $columns = sqlite_table_columns($dbh, 'sample');
	is(scalar(@$columns), 3, 'table columns listed');
	my $identity = sqlite_identity($dbh, $objects->[0], $columns);
	is($identity->{'rowid'}, 'rowid', 'rowid selected for stable identity');
	my $result = sqlite_query($dbh, 'SELECT name FROM sample', 10);
	is_deeply($result->{'rows'}, [ [ 'first' ] ], 'query returns row data');

	# A filename that resembles extra DBD parameters remains the literal
	# validated filename instead of selecting a second database path.
	my $injected = "$outside/injected.db";
	my $crafted = "$allowed/literal;dbname=$injected";
	(my $crafted_parent = $crafted) =~ s!/[^/]+$!!;
	make_path($crafted_parent);
	my $crafted_dbh = sqlite_connect($crafted, 1, 1);
	my $resolved_crafted = simplify_path(resolve_links($crafted));
	is($crafted_dbh->sqlite_db_filename(), $resolved_crafted,
		'DBD opens the validated filename containing connection syntax');
	$crafted_dbh->disconnect();
	ok(-f $crafted, 'literal crafted filename is created inside the ACL');
	ok(!-e $injected, 'second dbname text cannot escape the path ACL');
	# A second statement is refused before anything runs, and the
	# single-statement rule stays in force afterwards.
	$text{'exec_multiple'} = 'Only one SQL statement can be run at a time';
	eval { sqlite_query($dbh, 'SELECT name FROM sample; DROP TABLE sample', 10) };
	like($@, qr/^Only one SQL statement/, 'a second statement is refused');
	ok(sqlite_object($dbh, 'sample'), 'and the refused statement did not run');
	ok(!$dbh->{'sqlite_allow_multiple_statements'},
		'multiple statements stay disabled after the check');
	$dbh->do('INSERT INTO sample (name) VALUES (?)', undef, 'second');
	my $limited = sqlite_query($dbh, 'SELECT name FROM sample ORDER BY id', 1);
	is_deeply($limited->{'rows'}, [ [ 'first' ] ], 'query result honors row limit');
	ok($limited->{'truncated'}, 'limited query reports truncation');
	ok(sqlite_value_is_binary("a\0b"), 'binary value detected');
	ok(!sqlite_value_is_binary('plain text'), 'text value detected');

	# Keep an ASCII-only BLOB binary without fetching its bytes.
	$dbh->do('CREATE TABLE blob_sample (id INTEGER PRIMARY KEY, data BLOB)');
	my $blob_insert = $dbh->prepare(
		'INSERT INTO blob_sample (data) VALUES (?)');
	$blob_insert->bind_param(1, 'ascii blob', DBI::SQL_BLOB());
	$blob_insert->execute();
	my $blob_columns = sqlite_table_columns($dbh, 'blob_sample');
	my ($blob_values, $blob_types, $blob_lengths) =
		sqlite_column_selects($blob_columns);
	my $blob_row = $dbh->selectrow_arrayref('SELECT '.join(', ',
		@$blob_values, @$blob_types, @$blob_lengths).' FROM blob_sample');
	is($blob_row->[1], undef, 'bounded row query omits the BLOB payload');
	is($blob_row->[3], 'blob', 'bounded row query preserves the storage type');
	is($blob_row->[5], 10, 'bounded row query preserves the BLOB length');
	is(sqlite_display_value($blob_row->[1], $blob_row->[3], $blob_row->[5]),
		'[binary value, 10 bytes]', 'ASCII BLOB is displayed as binary');

	# Check quoted identifiers and WITHOUT ROWID identities.
	my $odd_table = 'odd "table';
	$dbh->do('CREATE TABLE '.sqlite_quote_identifier($odd_table).
		' (first TEXT, second INTEGER, PRIMARY KEY (first, second)) WITHOUT ROWID');
	my $odd_object = sqlite_object($dbh, $odd_table);
	is($odd_object->{'type'}, 'table', 'quoted table name is found');
	my $odd_columns = sqlite_table_columns($dbh, $odd_table);
	is(scalar(@$odd_columns), 2, 'quoted table columns are listed');
	is_deeply(sqlite_identity($dbh, $odd_object, $odd_columns),
		{ 'columns' => [ 'first', 'second' ] },
		'WITHOUT ROWID table uses its composite primary key');
	$dbh->do('CREATE VIEW sample_view AS SELECT name FROM sample');
	my $view = sqlite_object($dbh, 'sample_view');
	ok(!sqlite_identity($dbh, $view, sqlite_table_columns($dbh, 'sample_view')),
		'view is not editable');
	ok(!sqlite_object($dbh, 'sqlite_sequence'),
		'internal SQLite table cannot be browsed directly');

	# Check read-only connections and authorizer restrictions.
	my $readonly = sqlite_connect($database, 0);
	my ($query_only) = $readonly->selectrow_array('PRAGMA query_only');
	is($query_only, 1, 'read-only connection enables query-only mode');
	my $wrote_readonly = eval {
		$readonly->do("INSERT INTO sample (name) VALUES ('blocked')");
		1;
		};
	ok(!$wrote_readonly, 'read-only connection rejects writes');
	$readonly->disconnect();
	sqlite_install_authorizer($dbh);
	my $attached = eval { $dbh->do("ATTACH DATABASE '$outside/other.db' AS other"); 1 };
	ok(!$attached, 'authorizer rejects attached database');
	ok(!-e "$outside/other.db", 'rejected attachment creates no file');
	my $vacuumed = eval { $dbh->do("VACUUM INTO '$outside/vacuum.db'"); 1 };
	ok(!$vacuumed, 'authorizer rejects VACUUM INTO');
	ok(!-e "$outside/vacuum.db", 'rejected VACUUM creates no file');
	$dbh->disconnect();
	}

done_testing();
