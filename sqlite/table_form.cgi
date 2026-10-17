#!/usr/local/bin/perl
# Displays the form for creating a new table.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();

# Only a writable, valid database can take a new table.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 0);
$dbh->disconnect();

# Start with four column rows, or as many as the caller asked for.
my $count = int($in{'fields'} || 4);
$count = 1 if ($count < 1);
$count = 50 if ($count > 50);

&ui_print_header(&ui_tag('tt', &html_escape($path)), $text{'create_title'},
	'', 'create');
print &ui_page_start();
print &sqlite_table_form($path, \%in, $count);
print &ui_page_end();
&ui_print_footer('database.cgi?db='.&urlize($path),
	$text{'database_return'}, '', $text{'index_return'});
