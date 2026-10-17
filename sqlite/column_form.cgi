#!/usr/local/bin/perl
# Displays the form for adding a column to a table, or for renaming one.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();

# Structure changes need a writable table; views cannot be altered.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 0);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
$dbh->disconnect();

my $existing;
# Renaming needs the column to still exist and the library to support it.
if ($in{'column'} ne '') {
	($existing) = grep { $_->{'name'} eq $in{'column'} } @$columns;
	$existing || &error($text{'column_emissing'});
	&sqlite_supports('rename_column') ||
		&error($text{'column_eunsupported'});
	}

my $desc = &ui_tag('tt', &html_escape($object->{'name'})).
	$text{'table_in'}.' '.&ui_tag('tt', &html_escape($path));
&ui_print_header($desc,
	$text{$existing ? 'column_title_rename' : 'column_title_add'}, '',
	'column');
print &ui_form_start('save_column.cgi', 'post');
print &ui_hidden('db', $path);
print &ui_hidden('table', $object->{'name'});
print &ui_hidden('mode', $existing ? 'rename' : 'add');
print &ui_table_start($text{$existing ? 'column_header_rename' :
	'column_header_add'}, 'width=100%', 2);
# A rename shows the current name and asks for the new one only.
if ($existing) {
	print &ui_hidden('column', $existing->{'name'});
	print &ui_table_row($text{'column_current'},
		&ui_tag('tt', &html_escape($existing->{'name'})).' '.
		&ui_tag('small', &html_escape($existing->{'type'} ||
			$text{'edit_untyped'})));
	print &ui_table_row($text{'column_newname'},
		&ui_textbox('name', $existing->{'name'}, 40));
	}
else {
	# A new column takes a name, a type, a NULL rule and a default.
	print &ui_table_row($text{'column_name'},
		&ui_textbox('name', $in{'name'}, 40));
	print &ui_table_row($text{'column_type'},
		&ui_select('type', $in{'type'} || 'TEXT',
			[ map { [ $_ ] } &sqlite_column_types() ]));
	print &ui_table_row($text{'column_null'},
		&ui_yesno_radio('null', defined($in{'null'}) ? $in{'null'} : 1));
	print &ui_table_row($text{'column_default'},
		&ui_textbox('default', $in{'default'}, 30).' '.
		&ui_help($text{'column_default_help'}));
	}
print &ui_table_end();
print &ui_form_end([ [ undef,
	$text{$existing ? 'column_rename' : 'column_add'} ] ]);
&ui_print_footer('table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&view=structure', $text{'column_return'});
