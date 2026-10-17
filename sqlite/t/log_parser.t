#!/usr/bin/perl
# Tests readable, escaped SQLite action-log descriptions.

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

BEGIN { $ENV{'SQLITE_TESTING'} = 1; }
chdir "$FindBin::Bin/.." or die "chdir: $!";
require 'log_parser.pl';

our %text;
%text = (
	'log_database_create' => 'Created SQLite database $1',
	'log_table_create' => 'Created table $1 in database $2',
	'log_table_drop' => 'Dropped table $1 from database $2',
	'log_table_rename' => 'Renamed table $1 to $2 in database $3',
	'log_view_drop' => 'Dropped view $1 from database $2',
	'log_column_create' => 'Added column $1 to table $2 in database $3',
	'log_column_rename' =>
		'Renamed column $1 to $2 in table $3 in database $4',
	'log_column_rename_old' =>
		'Renamed column $1 in table $2 in database $3',
	'log_column_drop' => 'Dropped column $1 from table $2 in database $3',
	'log_row_create' => 'Added a row to table $1 in database $2',
	'log_row_modify' => 'Updated a row in table $1 in database $2',
	'log_rows_delete' => 'Deleted $1 rows from table $2 in database $3',
	'log_sql_exec' => 'Executed SQL in database $1',
	'log_sql_exec_long' => 'Executed SQL statement $2 in database $1',
	);

# sub describe(action, type, object, [&params], [long])
# Calls the parser with fixed user and script fields for a concise test.
sub describe
{
my ($action, $type, $object, $params, $long) = @_;
return parse_webmin_log('root', 'test.cgi', $action, $type, $object,
	$params || { }, $long);
}

# sub normalize_description(html)
# Removes ui_tag's marker class and folds formatting whitespace so expected
# sentences stay readable in these tests.
sub normalize_description
{
my ($html) = @_;
$html =~ s/ class="ui--tt"//g;
$html =~ s/\s+/ /g;
$html =~ s/^ | $//g;
return $html;
}

is(normalize_description(describe('create', 'database', '/srv/app.db')),
	'Created SQLite database <tt>/srv/app.db</tt>',
	'database creation has a readable description');
is(normalize_description(describe('create', 'table', 'jobs', {
	'db' => '/srv/app.db' })),
	'Created table <tt>jobs</tt> in database <tt>/srv/app.db</tt>',
	'table creation names its database');
is(normalize_description(describe('rename', 'table', 'jobs', {
	'db' => '/srv/app.db', 'name' => 'tasks' })),
	'Renamed table <tt>jobs</tt> to <tt>tasks</tt> in database <tt>/srv/app.db</tt>',
	'table rename shows both names');
is(normalize_description(describe('rename', 'column', 'owner', {
	'db' => '/srv/app.db', 'table' => 'jobs', 'name' => 'owner_name' })),
	'Renamed column <tt>owner</tt> to <tt>owner_name</tt> in table <tt>jobs</tt> in database <tt>/srv/app.db</tt>',
	'column rename shows both names and its table');
is(normalize_description(describe('rename', 'column', 'owner2', {
	'db' => '/srv/app.db', 'table' => 'jobs' })),
	'Renamed column <tt>owner2</tt> in table <tt>jobs</tt> in database <tt>/srv/app.db</tt>',
	'older column rename records still get a useful description');
is(normalize_description(describe('delete', 'rows', '2', {
	'db' => '/srv/app.db', 'table' => 'jobs' })),
	'Deleted 2 rows from table <tt>jobs</tt> in database <tt>/srv/app.db</tt>',
	'row deletion names its count, table and database');
is(normalize_description(describe('exec', 'sql', '/srv/app.db', {
	'sql' => 'SELECT <script>' }, 1)),
	'Executed SQL statement <tt>SELECT &lt;script&gt;</tt> in database <tt>/srv/app.db</tt>',
	'long SQL descriptions escape statement text');
is(normalize_description(describe('rename', 'column', '<b>', {
	'db' => '/srv/<db>', 'table' => '<table>', 'name' => '<new>' })),
	'Renamed column <tt>&lt;b&gt;</tt> to <tt>&lt;new&gt;</tt> in table <tt>&lt;table&gt;</tt> in database <tt>/srv/&lt;db&gt;</tt>',
	'logged names and paths cannot inject HTML');
is(describe('unknown', 'thing', 'item'), undef,
	'unknown records use the action-log fallback');
like(describe('create', 'database', '/srv/app.db'),
	qr/<tt class="ui--tt">\/srv\/app\.db<\/tt>/,
	'log descriptions build markup through ui_tag');

done_testing();
