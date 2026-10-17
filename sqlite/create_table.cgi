#!/usr/local/bin/perl
# Creates a table from the table form, or shows the form again with more
# column rows.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'create_err'});

# Recheck write access before anything else.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
# Keep the row count the form carried between one and fifty.
my $count = int($in{'fields'} || 4);
$count = 1 if ($count < 1);
$count = 50 if ($count > 50);

# Show the form again with more rows, keeping what was typed so far.
if ($in{'more'}) {
	$count += 4;
	$count = 50 if ($count > 50);
	&ui_print_header(&ui_tag('tt', &html_escape($path)),
		$text{'create_title'}, '', 'create');
	print &ui_page_start();
	print &sqlite_table_form($path, \%in, $count);
	print &ui_page_end();
	&ui_print_footer('database.cgi?db='.&urlize($path),
		$text{'database_return'}, '', $text{'index_return'});
	exit;
	}

# Collect the rows that were filled in, skipping blank ones.
my @columns;
for(my $i = 0; $i < $count; $i++) {
	my $name = $in{'name_'.$i};
	$name =~ s/^\s+|\s+$//g;
	next if ($name eq '');
	push(@columns, {
		'name' => $name,
		'type' => $in{'type_'.$i},
		'null' => $in{'null_'.$i} ? 1 : 0,
		'key' => $in{'key_'.$i},
		'default' => $in{'default_'.$i},
		});
	}
my $name = $in{'name'};
$name =~ s/^\s+|\s+$//g;
my $sql = eval { &sqlite_create_table_sql($name, \@columns) };
# Report a definition problem as a form error.
if ($@) {
	my $message = $@;
	chomp($message);
	&error($message);
	}

my $dbh = &sqlite_connect($path, 1);
# Refuse to replace an existing table or view.
if (&sqlite_object($dbh, $name)) {
	$dbh->disconnect();
	&error(&text('create_eexists', &html_escape($name)));
	}
eval { $dbh->do($sql); };
# Pass SQLite's own objection through the normal error page.
if ($@) {
	my $message = $@;
	$dbh->disconnect();
	&error(&html_escape($message));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&webmin_log('create', 'table', $name, { 'db' => $path });
&redirect('table.cgi?db='.&urlize($path).'&table='.&urlize($name).
	'&view=structure');
