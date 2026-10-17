#!/usr/local/bin/perl
# Lists the tables and views in an SQLite database.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access);
require './sqlite-lib.pl';
&ReadParse();

# Read objects and summary metrics through a read-only connection.
my $path = &sqlite_database_path($in{'db'});
my $dbh = &sqlite_connect($path, 0);
my $objects = &sqlite_objects($dbh);
my ($journal) = $dbh->selectrow_array('PRAGMA journal_mode');
my ($page_count) = $dbh->selectrow_array('PRAGMA page_count');
my ($page_size) = $dbh->selectrow_array('PRAGMA page_size');
my ($user_version) = $dbh->selectrow_array('PRAGMA user_version');
$dbh->disconnect();
# Put a database that opened successfully at the top of the recent list.
&sqlite_remember_recent($path,
	scalar(grep { $_->{'type'} eq 'table' } @$objects));

# Show database metrics above the object list.
&ui_print_header(&ui_tag('tt', &html_escape($path)),
	$text{'database_title'}, '', 'database');
print &ui_page_start();
print &ui_tag('style',
	'.sqlite_database_stats .ui_stat_value { font-size: 1.48em; }',
	{ 'type' => 'text/css' });
my $wal = lc($journal) eq 'wal';
my $writable = &sqlite_can_write($path);
my $sql_writable = &sqlite_can_sql_write($path);
my $database_writable = $writable || $sql_writable;
print &ui_grid([
	&ui_card({
		'title' => $text{'database_size'},
		'body' => &ui_stat({
			'value_html' => &nice_size($page_count * $page_size),
			'icon' => 'hard-drive',
			}),
		}),
	&ui_card({
		'title' => $text{'database_journal'},
		'actions' => $wal ? undef : &ui_help($text{'database_wal'}),
		'body' => &ui_stat({
			'value' => uc($journal),
			'icon' => 'database',
			'state' => $wal ? 'success' : 'info',
			}),
		'state' => $wal ? 'success' : 'info',
		}),
	&ui_card({
		'title' => $text{'database_version'},
		'body' => &ui_stat({
			'value' => int($user_version),
			'icon' => 'tag',
			}),
		}),
	&ui_card({
		'title' => $text{'database_access'},
		'body' => &ui_stat({
			'value' => $database_writable ? $text{'database_readwrite'} :
				$text{'database_readonly'},
			'icon' => $database_writable ? 'edit' : 'lock',
			'state' => $database_writable ? 'success' : 'neutral',
			}),
		'state' => $database_writable ? 'success' : undef,
		}),
	], { 'min' => '210px', 'gap' => '12px',
	       'class' => 'sqlite_database_stats' });

# Structured write access offers table creation above a populated list or in
# the empty state.
my $create_url = 'table_form.cgi?db='.&urlize($path);

# List user tables and views when present.
if (@$objects) {
	# Offer the table form above the list to users who can write.
	if ($writable) {
		print &ui_form_start('table_form.cgi');
		print &ui_hidden('db', $path);
		print &ui_form_end([ [ undef, $text{'database_create_button'} ] ]);
		}
	print &ui_columns_start([
		$text{'database_name'}, $text{'database_type'},
		$text{'database_definition'}, $text{'database_action'} ],
		100, 0, undef, undef, 1);
	foreach my $object (@$objects) {
		my $link = 'table.cgi?db='.&urlize($path).
			'&table='.&urlize($object->{'name'});
		my $sql = $object->{'sql'} || '';
		$sql =~ s/\s+/ /g;
		# Keep large schema definitions from dominating the object list.
		$sql = substr($sql, 0, 160).$text{'value_more'}
			if (length($sql) > 160);
		print &ui_columns_row([
			&ui_tag('a', &html_escape($object->{'name'}), {
				'href' => $link,
				'style' => 'display:inline-block;white-space:nowrap;',
				}),
			&html_escape($text{'database_'.$object->{'type'}}),
			&ui_tag('tt', &html_escape($sql), {
				'style' => 'white-space:normal;overflow-wrap:anywhere;',
				}),
			&ui_tag('a', $text{'database_browse'}, { 'href' => $link }),
			]);
		}
	print &ui_columns_end();
	}
else {
	# Show guidance instead of an empty object table: offer the table form
	# with structured write access, or point SQL-only users to that page.
	print &ui_empty_state({
		'title' => $text{'database_empty'},
		'desc' => $writable ? $text{'database_empty_create'} :
			  $sql_writable ? $text{'database_empty_sql'} : undef,
		'icon' => 'database',
		'actions' => $writable ?
			&ui_action_button($text{'database_create_button'}, 'success', {
				'href' => $create_url, 'icon' => 'plus' }) : undef,
		});
	}

# Direct SQL is visible only when explicitly enabled in the module ACL.
if ($access{'sql'}) {
	print &ui_form_start('exec_form.cgi');
	print &ui_hidden('db', $path);
	print &ui_form_end([ [ undef, $text{'database_sql'} ] ]);
	}
print &ui_page_end();
&ui_print_footer('', $text{'index_return'});
