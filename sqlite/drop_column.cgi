#!/usr/local/bin/perl
# Confirms and drops one column from a table.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'dropcol_err'});

# Recheck write access, library support and the column itself.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
&sqlite_supports('drop_column') || &error($text{'column_eunsupported'});
my $dbh = &sqlite_connect($path, 0);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my ($column) = grep { $_->{'name'} eq $in{'column'} }
		    @{&sqlite_table_columns($dbh, $object->{'name'})};
$column || &error($text{'column_emissing'});
my $quoted_table = &sqlite_quote_identifier($object->{'name'});
my $structure = 'table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&view=structure';

# Always ask first, since the dropped values cannot be recovered.
if (!$in{'confirm'}) {
	my ($rows) = $dbh->selectrow_array('SELECT count(*) FROM '.$quoted_table);
	$dbh->disconnect();
	&ui_print_header(undef, $text{'dropcol_title'}, '', 'drop_column');
	print &ui_confirmation_form('drop_column.cgi',
		&text('dropcol_confirm',
			&ui_tag('tt', &html_escape($column->{'name'})),
			&ui_tag('tt', &html_escape($object->{'name'})), $rows),
		[ [ 'db', $path ], [ 'table', $object->{'name'} ],
		  [ 'column', $column->{'name'} ] ],
		[ [ 'confirm', $text{'dropcol_ok'} ] ]);
	&ui_print_footer($structure, $text{'column_return'});
	exit;
	}
$dbh->disconnect();

$dbh = &sqlite_connect($path, 1);
eval { $dbh->do('ALTER TABLE '.$quoted_table.' DROP COLUMN '.
		&sqlite_quote_identifier($column->{'name'})); };
# SQLite refuses to drop key, unique, indexed and referenced columns, and
# says so in its own words.
if ($@) {
	my $message = $@;
	$dbh->disconnect();
	&error(&html_escape($message));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&webmin_log('drop', 'column', $column->{'name'},
	{ 'db' => $path, 'table' => $object->{'name'} });
&redirect($structure);
