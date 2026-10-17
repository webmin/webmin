#!/usr/local/bin/perl
# Confirms and drops one table or view.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'drop_err'});

# Recheck write access and find the object to drop.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 0);
my $object = &sqlite_object($dbh, $in{'table'});
$object || &error($text{'table_missing'});
my $is_view = $object->{'type'} eq 'view';
my $quoted = &sqlite_quote_identifier($object->{'name'});

# Always ask first, since a dropped table or view cannot be recovered here.
if (!$in{'confirm'}) {
	my $message;
	# Say how many rows a table holds; a view holds none of its own.
	if ($is_view) {
		$message = &text('drop_confirm_view',
			&ui_tag('tt', &html_escape($object->{'name'})));
		}
	else {
		# Count the table's rows for the warning.
		my ($rows) = $dbh->selectrow_array('SELECT count(*) FROM '.$quoted);
		$message = &text('drop_confirm',
			&ui_tag('tt', &html_escape($object->{'name'})), $rows);
		}
	$dbh->disconnect();
	&ui_print_header(undef,
		$text{$is_view ? 'table_drop_view' : 'table_drop'}, '',
		'drop_table');
	print &ui_confirmation_form('drop_table.cgi', $message,
		[ [ 'db', $path ], [ 'table', $object->{'name'} ] ],
		[ [ 'confirm', $text{$is_view ? 'table_drop_view' : 'table_drop'} ] ]);
	&ui_print_footer('table.cgi?db='.&urlize($path).'&table='.
		&urlize($object->{'name'}), $text{'table_return'});
	exit;
	}
$dbh->disconnect();

# Drop through a read-write connection.
$dbh = &sqlite_connect($path, 1);
eval { $dbh->do(($is_view ? 'DROP VIEW ' : 'DROP TABLE ').$quoted); };
# Report SQLite's own objection through the normal error page.
if ($@) {
	my $message = $@;
	$dbh->disconnect();
	&error(&html_escape($message));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&webmin_log('drop', $is_view ? 'view' : 'table', $object->{'name'},
	{ 'db' => $path });
&redirect('database.cgi?db='.&urlize($path));
