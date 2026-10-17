# log_parser.pl
# Converts SQLite module action-log records into readable descriptions.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
do 'sqlite-lib.pl';
our (%text);

# sub parse_webmin_log(user, script, action, type, object, &params, [long])
# Returns a human-readable description for one SQLite action-log record.
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $params, $long) = @_;
$params ||= { };

# Escape every logged name and path before adding the intended markup.
my $item = &ui_tag('tt', &html_escape($object));
my $database = &ui_tag('tt', &html_escape($params->{'db'}));
my $table = &ui_tag('tt', &html_escape($params->{'table'}));

# Database creation logs the full database path as the object.
if ($type eq 'database' && $action eq 'create') {
	return &text('log_database_create', $item);
	}
# Table and view actions include the database that contains the object.
elsif (($type eq 'table' || $type eq 'view') &&
       ($action eq 'create' || $action eq 'drop')) {
	return &text('log_'.$type.'_'.$action, $item, $database);
	}
elsif ($type eq 'table' && $action eq 'rename') {
	return &text('log_table_rename', $item,
		&ui_tag('tt', &html_escape($params->{'name'})), $database);
	}
# Column actions also name their table. New rename records carry both names;
# older records fall back to the single name they stored as the object.
elsif ($type eq 'column' && $action eq 'create') {
	return &text('log_column_create', $item, $table, $database);
	}
elsif ($type eq 'column' && $action eq 'rename') {
	return $params->{'name'} ne '' ?
		&text('log_column_rename', $item,
			&ui_tag('tt', &html_escape($params->{'name'})),
			$table, $database) :
		&text('log_column_rename_old', $item, $table, $database);
	}
elsif ($type eq 'column' && $action eq 'drop') {
	return &text('log_column_drop', $item, $table, $database);
	}
# Row changes use the table name as the logged object.
elsif ($type eq 'row' && ($action eq 'create' || $action eq 'modify')) {
	return &text('log_row_'.$action, $item, $database);
	}
elsif ($type eq 'rows' && $action eq 'delete') {
	my $count = $object =~ /^\d+$/ ? int($object) : 0;
	return &text('log_rows_delete', $count, $table, $database);
	}
# The short form omits SQL text from the action list; the details page can
# show the escaped statement.
elsif ($type eq 'sql' && $action eq 'exec') {
	return &text($long ? 'log_sql_exec_long' : 'log_sql_exec', $item,
		&ui_tag('tt', &html_escape($params->{'sql'})));
	}
return undef;
}

1;
