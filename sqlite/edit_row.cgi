#!/usr/local/bin/perl
# Displays a form for adding or editing a table row.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();

# Require a writable table with a stable row identity.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 0);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
my $identity = &sqlite_identity($dbh, $object, $columns);
$identity || &error($text{'table_noidentity'});

my @values = map { undef } @$columns;
my @storage_types = map { undef } @$columns;
my @storage_lengths = map { undef } @$columns;
# Load one existing row. New rows start with undefined values.
if (!$in{'new'}) {
	my $count = $identity->{'rowid'} ? 1 : scalar(@{$identity->{'columns'}});
	my @keys = &sqlite_decode_key($in{'key'}, $count);
	my ($where, @params) = &sqlite_identity_where($identity, \@keys);
	my ($value_selects, $type_selects, $length_selects) =
		&sqlite_column_selects($columns);
	my $sql = 'SELECT '.join(', ', @$value_selects, @$type_selects,
		@$length_selects).
		' FROM '.&sqlite_quote_identifier($object->{'name'}).
		' WHERE '.$where.' LIMIT 2';
	my $rows = $dbh->selectall_arrayref($sql, undef, @params);
	@$rows == 1 || &error($text{'edit_missing'});
	my @selected = @{$rows->[0]};
	@values = splice(@selected, 0, scalar(@$columns));
	@storage_types = splice(@selected, 0, scalar(@$columns));
	@storage_lengths = splice(@selected, 0, scalar(@$columns));
	}
$dbh->disconnect();

# Carry the database, table and row identity into the save request.
&ui_print_header(undef, $in{'new'} ? $text{'edit_title_new'} :
	$text{'edit_title'}, '', 'edit_row');
print &ui_form_start('save_row.cgi', 'post');
print &ui_hidden('db', $path);
print &ui_hidden('table', $object->{'name'});
print &ui_hidden('new', $in{'new'} ? 1 : 0);
# Existing rows must carry their opaque identity into the update request.
print &ui_hidden('key', $in{'key'}) if (!$in{'new'});
print &ui_hidden('start', int($in{'start'} || 0));
print &ui_table_start($text{'edit_header'}, undef, 3);
for(my $i = 0; $i < @$columns; $i++) {
	my $column = $columns->[$i];
	my $value = $values[$i];
	my $details = &html_escape($column->{'type'} || $text{'edit_untyped'});
	# Mark declared NOT NULL columns as required context for the user.
	$details .= ', '.$text{'edit_required'} if ($column->{'notnull'});
	# Mark generated columns before rendering them as read-only values.
	$details .= ', '.$text{'table_generated'} if ($column->{'hidden'} == 2 ||
		$column->{'hidden'} == 3);
	my $input;
	# Generated columns are displayed but never submitted for modification.
	if ($column->{'hidden'} == 2 || $column->{'hidden'} == 3) {
		$input = &sqlite_display_value($value, $storage_types[$i],
			$storage_lengths[$i]);
		}
	elsif (!$in{'new'} && ((defined($storage_types[$i]) &&
		$storage_types[$i] eq 'blob') ||
		&sqlite_value_is_binary($value))) {
		# Preserve binary data because the form cannot edit it.
		my $length = defined($storage_lengths[$i]) ?
			$storage_lengths[$i] : length($value);
		$input = &text('edit_blob', $length).
			&ui_hidden('keep_'.$i, 1);
		}
	else {
		# Text and NULL values use the normal editable controls.
		$input = &ui_textarea('value_'.$i, defined($value) ? $value : '',
			3, 60, undef, undef, "style='width: 100%'");
		$input .= &ui_tag('br').&ui_checkbox('null_'.$i, 1,
			$text{'edit_null'}, !defined($value) && !$in{'new'});
		# Let SQLite supply declared defaults and integer primary keys
		# on insert.
		if ($in{'new'} && (defined($column->{'dflt_value'}) ||
			$column->{'pk'} && $column->{'type'} =~ /^INTEGER$/i)) {
			$input .= ' '.&ui_checkbox('default_'.$i, 1,
				$text{'edit_default'}, 1);
			}
		}
	# Use the full-width row layout in themes that support it.
	print &ui_table_row(&html_escape($column->{'name'}).&ui_tag('br').
		&ui_tag('small', $details), $input, 2, undef, undef, 1);
	}
print &ui_table_end();
print &ui_form_end([ [ undef, $in{'new'} ? $text{'edit_create'} :
	$text{'save'} ] ]);

&ui_print_footer('table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}), $text{'table_return'});
