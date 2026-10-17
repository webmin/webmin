#!/usr/local/bin/perl
# Adds a column to a table or renames an existing one.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'column_err'});

# Recheck write access and reload the schema before changing it.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 1);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
# Column names are compared without regard to case, as SQLite does.
my %names = map { lc($_->{'name'}) => 1 } @$columns;
my $name = $in{'name'};
$name =~ s/^\s+|\s+$//g;

my ($sql, $action, $old_name);
if ($in{'mode'} eq 'rename') {
	# Renaming keeps everything about the column but its name.
	&sqlite_supports('rename_column') ||
		&error($text{'column_eunsupported'});
	my ($existing) = grep { $_->{'name'} eq $in{'column'} } @$columns;
	$existing || &error($text{'column_emissing'});
	&sqlite_valid_name($name) ||
		&error(&text('create_ecolumn', &html_escape($name)));
	# The same name again is not an error, just nothing to do.
	if ($name eq $existing->{'name'}) {
		$dbh->disconnect();
		&redirect('table.cgi?db='.&urlize($path).'&table='.
			&urlize($object->{'name'}).'&view=structure');
		exit;
		}
	!$names{lc($name)} || lc($name) eq lc($existing->{'name'}) ||
		&error(&text('column_eexists', &html_escape($name)));
	$sql = 'ALTER TABLE '.&sqlite_quote_identifier($object->{'name'}).
		' RENAME COLUMN '.&sqlite_quote_identifier($existing->{'name'}).
		' TO '.&sqlite_quote_identifier($name);
	$action = 'rename';
	$old_name = $existing->{'name'};
	}
else {
	# Adding validates the definition the way the table form does.
	$sql = eval { &sqlite_add_column_sql($object->{'name'}, {
		'name' => $name,
		'type' => $in{'type'},
		'null' => $in{'null'} ? 1 : 0,
		'default' => $in{'default'} }) };
	# Report a definition problem as a form error.
	if ($@) {
		my $message = $@;
		chomp($message);
		&error($message);
		}
	!$names{lc($name)} ||
		&error(&text('column_eexists', &html_escape($name)));
	$action = 'create';
	}

# Run the change.
eval { $dbh->do($sql); };
# Pass SQLite's own objection through the normal error page.
if ($@) {
	my $message = $@;
	$dbh->disconnect();
	&error(&html_escape($message));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
# A rename stores both names so the action log can describe the change.
&webmin_log($action, 'column', $old_name || $name,
	{ 'db' => $path, 'table' => $object->{'name'},
	  $action eq 'rename' ? ( 'name' => $name ) : ( ) });
&redirect('table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&view=structure');
