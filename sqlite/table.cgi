#!/usr/local/bin/perl
# Displays a table or view schema and a page of data.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %in, %access);
require './sqlite-lib.pl';
&ReadParse();

# Load the object and find a stable row identity.
my $path = &sqlite_database_path($in{'db'});
my $dbh = &sqlite_connect($path, 0);
my $object = &sqlite_object($dbh, $in{'table'});
$object || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
@$columns || &error($text{'table_nocolumns'});
my $identity = &sqlite_identity($dbh, $object, $columns);
my $editable = $identity && &sqlite_can_write($path);

# Clamp pagination inputs before using them in the query.
my $perpage = int($config{'perpage'} || 50);
# Use one row as the minimum page size.
$perpage = 1 if ($perpage < 1);
# Cap each page at 1,000 rows.
$perpage = 1000 if ($perpage > 1000);
my $start = int($in{'start'} || 0);
# Negative offsets return the first page.
$start = 0 if ($start < 0);
my $quoted_table = &sqlite_quote_identifier($object->{'name'});
my ($total) = $dbh->selectrow_array('SELECT count(*) FROM '.$quoted_table);
# Move an out-of-range offset to the last populated page.
$start = int(($total - 1) / $perpage) * $perpage
	if ($total && $start >= $total);

# Accept sorting only by a column returned from the database schema.
my %column_names = map { $_->{'name'} => 1 } @$columns;
my $sort = $column_names{$in{'sort'}} ? $in{'sort'} : undef;
my $order = $sort ? ' ORDER BY '.&sqlite_quote_identifier($sort).
	($in{'desc'} ? ' DESC' : ' ASC') : '';
my %identity_columns = $identity && !$identity->{'rowid'} ?
	map { $_ => 1 } @{$identity->{'columns'}} : ( );
my ($value_selects, $type_selects, $length_selects) =
	&sqlite_column_selects($columns, \%identity_columns);
my @select = (@$value_selects, @$type_selects, @$length_selects);
# Select rowid separately when it is the stable editing identity.
if ($identity && $identity->{'rowid'}) {
	unshift(@select, $identity->{'rowid'});
	}
# Fetch one page with the storage metadata needed for safe rendering.
my $sth = $dbh->prepare('SELECT '.join(', ', @select).' FROM '.
	$quoted_table.$order.' LIMIT ? OFFSET ?');
$sth->execute($perpage, $start);
my @rows;
while (my $row = $sth->fetchrow_arrayref()) {
	push(@rows, [ @$row ]);
	}
$sth->finish();
$dbh->disconnect();

my $desc = &ui_tag('tt', &html_escape($object->{'name'})).' '.
	$text{'table_in'}.' '.&ui_tag('tt', &html_escape($path));
&ui_print_header($desc, $text{'table_title'}, '', 'table');
print &ui_page_start();

# Split schema and row data into independent tabs.
my $view = $in{'view'} eq 'structure' ? 'structure' : 'data';
print &ui_tabs_start([
	[ 'structure', $text{'table_structure'} ],
	[ 'data', $text{'table_data'} ],
	], 'view', $view, 1);

print &ui_tabs_start_tab('view', 'structure');
# Structure changes need a writable table, since views cannot be altered,
# and column renames and drops also need a recent enough SQLite.
my $writable = &sqlite_can_write($path);
my $can_alter = $writable && $object->{'type'} eq 'table';
my $rename_columns = $can_alter && &sqlite_supports('rename_column');
my $drop_columns = $can_alter && &sqlite_supports('drop_column');
my $table_url = 'db='.&urlize($path).'&table='.&urlize($object->{'name'});
# Show each column's type, default and key information.
my @structure_heads = (
	$text{'table_column'}, $text{'table_type'}, $text{'table_null'},
	$text{'table_default'}, $text{'table_key'} );
push(@structure_heads, $text{'table_action'})
	if ($rename_columns || $drop_columns);
print &ui_columns_start(\@structure_heads, 100, 0, undef, undef, 1);
foreach my $column (@$columns) {
	my $key = $column->{'pk'} ? &text('table_pk', $column->{'pk'}) : '';
	# Generated columns are read-only even when they also belong to a key.
	$key = $text{'table_generated'} if ($column->{'hidden'} == 2 ||
		$column->{'hidden'} == 3);
	my @cells = (
		&html_escape($column->{'name'}),
		&html_escape($column->{'type'} || ''),
		$column->{'notnull'} ? $text{'no'} : $text{'yes'},
		defined($column->{'dflt_value'}) ?
			&ui_tag('tt', &html_escape($column->{'dflt_value'})) : '',
		$key,
		);
	# Offer the column actions the library supports.
	if ($rename_columns || $drop_columns) {
		my $column_url = $table_url.'&column='.&urlize($column->{'name'});
		my @actions;
		push(@actions, &ui_tag('a', $text{'table_rename_column'}, {
			'href' => 'column_form.cgi?'.$column_url,
			})) if ($rename_columns);
		# Key columns cannot be dropped, so no link is offered for them.
		push(@actions, &ui_tag('a', $text{'table_drop_column'}, {
			'href' => 'drop_column.cgi?'.$column_url,
			}))
			if ($drop_columns && !$column->{'pk'});
		push(@cells, join(' | ', @actions));
		}
	print &ui_columns_row(\@cells);
	}
print &ui_columns_end();
# Columns can be added to any writable table.
if ($can_alter) {
	print &ui_form_start('column_form.cgi');
	print &ui_hidden('db', $path);
	print &ui_hidden('table', $object->{'name'});
	print &ui_form_end([ [ undef, $text{'table_add_column'} ] ]);
	}
print &ui_tabs_end_tab('view', 'structure');

print &ui_tabs_start_tab('view', 'data');
# Explain why a table has no row actions.
if (!$identity && $object->{'type'} eq 'table') {
	print &ui_alert_box($text{'table_noidentity'}, 'warn', undef, undef, '');
	}
# The add-row action serves the empty state; the table footer has its own.
my $add_url = 'edit_row.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&new=1&start='.$start;
my $add_button = $editable ?
	&ui_action_button($text{'table_add'}, 'success', {
		'href' => $add_url, 'icon' => 'plus' }) : undef;
# Render the current page only when at least one row exists.
if (@rows) {
	# Column headings link to the view sorted by that column, flipping to
	# descending order when it is already the sort column.
	my @headers = map {
		my $name = $_->{'name'};
		my $next_desc = $sort && $sort eq $name && !$in{'desc'} ? 1 : 0;
		my $link = 'table.cgi?db='.&urlize($path).'&table='.
			&urlize($object->{'name'}).'&view=data&sort='.&urlize($name).
			($next_desc ? '&desc=1' : '');
		&ui_tag('a', &html_escape($name), { 'href' => $link });
		} @$columns;
	# Writable rows need a leading selection column.
	unshift(@headers, '') if ($editable);
	# Writable rows also need a trailing action column.
	push(@headers, $text{'table_action'}) if ($editable);
	my @table_rows;
	foreach my $row (@rows) {
		my @values = @$row;
		my @key_values;
		# Remove the leading rowid before splitting values from
		# metadata.
		if ($identity && $identity->{'rowid'}) {
			@key_values = (shift(@values));
			}
		my @storage_types = splice(@values, scalar(@$columns),
			scalar(@$columns));
		my @storage_lengths = splice(@values, scalar(@$columns),
			scalar(@$columns));
		# Build composite identities from their declared primary-key
		# columns.
		if ($identity && !$identity->{'rowid'}) {
			my %by_name;
			@by_name{map { $_->{'name'} } @$columns} = @values;
			@key_values = @by_name{@{$identity->{'columns'}}};
			}
		my $token = $identity ? &sqlite_encode_key(@key_values) : undef;
		my @shown = map {
			&sqlite_display_value($values[$_], $storage_types[$_],
				$storage_lengths[$_])
			} 0..$#values;
		# Mark writable rows for the standard checked-table renderer.
		unshift(@shown, {
			'type' => 'checkbox',
			'name' => 'row',
			'value' => $token,
			}) if ($editable);
		# Add an edit action only for writable rows.
		if ($editable) {
			my $edit = 'edit_row.cgi?db='.&urlize($path).'&table='.
				&urlize($object->{'name'}).'&key='.&urlize($token).
				'&start='.$start;
			push(@shown, &ui_tag('a', $text{'table_edit'}, {
				'href' => $edit,
				}));
			}
		push(@table_rows, \@shown);
		}

	# Build the row range and optional numbered navigation once for either
	# the writable or read-only table footer.
	my @controls = (
		&ui_tag('span',
			&html_escape(&text('table_position',
				$start + 1, $start + @rows, $total)),
			{ 'class' => 'sqlite_table_position' }),
		);
	# Add numbered navigation only when the result spans multiple pages.
	if ($total > $perpage) {
		my $pages = int(($total + $perpage - 1) / $perpage);
		my $page = int($start / $perpage) + 1;
		my $base = 'table.cgi?db='.&urlize($path).'&table='.
			&urlize($object->{'name'}).'&view=data'.
			($sort ? '&sort='.&urlize($sort) : '').
			($in{'desc'} ? '&desc=1' : '');
		push(@controls, &ui_pager({
			'page' => $page,
			'pages' => $pages,
			# sub page_url(page)
			# Returns the table URL for one pager page number.
			'url' => sub {
				return $base.'&start='.(($_[0] - 1) * $perpage);
				},
			'label' => $text{'table_pages'},
			}));
		}
	my $table_controls = &ui_cluster(\@controls, {
		'align' => 'between',
		'class' => 'sqlite_table_controls',
		});

	# Build the checked table and keep both bottom actions in one group.
	if ($editable) {
		print &ui_form_start('delete_rows.cgi', 'post');
		print &ui_hidden('db', $path);
		print &ui_hidden('table', $object->{'name'});
		print &ui_hidden('start', $start);
		my @select_links = (
			&select_all_link('row', 0),
			&select_invert_link('row', 0),
			);
		print &ui_links_row(\@select_links);
		print &ui_columns_table(\@headers, 100, \@table_rows, undef, 1);
		print &ui_links_row(\@select_links);
		my @add_actions = ([ undef, $text{'table_add'}, undef, 0,
			"form='sqlite_add_row_form'" ]);
		my @delete_actions = ([ 'delete', $text{'table_delete'} ]);
		my $actions = &ui_form_grouped_buttons([
			[ \@add_actions, \@delete_actions ],
			]);
		print &ui_stack([ $actions, $table_controls ], {
			'class' => 'sqlite_table_footer',
			});
		print &ui_form_end();

		# The Add Row submit targets its own form instead of the delete
		# form.
		print &ui_form_start('edit_row.cgi', 'get', undef,
			"id='sqlite_add_row_form' style='display:none;'");
		print &ui_hidden('db', $path);
		print &ui_hidden('table', $object->{'name'});
		print &ui_hidden('new', 1);
		print &ui_hidden('start', $start);
		print &ui_form_end();
		}
	else {
		# Read-only objects need only the table and its spaced footer.
		print &ui_columns_table(\@headers, 100, \@table_rows, undef, 1);
		print &ui_stack([ $table_controls ], {
			'class' => 'sqlite_table_footer',
			});
		}
	}
else {
	# Use a compact empty state instead of rendering a header-only table.
	print &ui_empty_state({
		'title' => $text{'table_empty'},
		'desc' => $editable ? $text{'table_empty_desc'} : undef,
		'icon' => 'database',
		'actions' => $add_button,
		});
	}

print &ui_tabs_end_tab('view', 'data');
print &ui_tabs_end(1);

# Structured write access permits renaming a table or dropping a table or
# view. The drop page asks for confirmation first.
if ($writable) {
	my $is_view = $object->{'type'} eq 'view';
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row('rename_table.cgi', $text{'table_rename'},
		$text{'table_rename_desc'},
		&ui_hidden('db', $path).&ui_hidden('table', $object->{'name'}),
		' '.&ui_textbox('name', $object->{'name'}, 30)) if (!$is_view);
	print &ui_buttons_row('drop_table.cgi',
		$text{$is_view ? 'table_drop_view' : 'table_drop'},
		$text{$is_view ? 'table_drop_view_desc' : 'table_drop_desc'},
		&ui_hidden('db', $path).&ui_hidden('table', $object->{'name'}));
	print &ui_buttons_end();
	}
print &ui_page_end();
&ui_print_footer('database.cgi?db='.&urlize($path),
	$text{'database_return'}, '', $text{'index_return'});
