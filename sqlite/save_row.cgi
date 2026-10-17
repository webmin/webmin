#!/usr/local/bin/perl
# Adds or updates one SQLite table row.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

# Recheck write access, table type and row identity.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 1);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
my $identity = &sqlite_identity($dbh, $object, $columns);
$identity || &error($text{'table_noidentity'});

# Build parameters from editable fields in the current schema.
my (@names, @values);
for(my $i = 0; $i < @$columns; $i++) {
	my $column = $columns->[$i];
	# SQLite computes generated columns.
	next if ($column->{'hidden'} == 2 || $column->{'hidden'} == 3);
	# Existing binary values carry a marker that leaves them unchanged.
	next if ($in{'keep_'.$i});
	# Omitted insert fields allow SQLite defaults to run.
	next if ($in{'new'} && $in{'default_'.$i});
	push(@names, $column->{'name'});
	push(@values, $in{'null_'.$i} ? undef : $in{'value_'.$i});
	}

# Run the insert or update in one transaction.
eval {
	$dbh->begin_work();
	# Insert only submitted columns, or use DEFAULT VALUES when none remain.
	if ($in{'new'}) {
		my $sql = @names ? 'INSERT INTO '.
			&sqlite_quote_identifier($object->{'name'}).' ('.
			join(', ', map { &sqlite_quote_identifier($_) } @names).') VALUES ('.
			join(', ', map { '?' } @names).')' :
			'INSERT INTO '.&sqlite_quote_identifier($object->{'name'}).
			' DEFAULT VALUES';
		$dbh->do($sql, undef, @values);
		}
	else {
		# Update the one row named by the validated opaque identity
		# token.
		@names || die $text{'save_nochanges'};
		my $count = $identity->{'rowid'} ? 1 :
			scalar(@{$identity->{'columns'}});
		my @keys = &sqlite_decode_key($in{'key'}, $count);
		my ($where, @key_params) = &sqlite_identity_where($identity, \@keys);
		my $sql = 'UPDATE '.&sqlite_quote_identifier($object->{'name'}).
			' SET '.join(', ', map {
				&sqlite_quote_identifier($_).' = ?' } @names).
			' WHERE '.$where;
		my $changed = $dbh->do($sql, undef, @values, @key_params);
		$changed && $changed > 0 || die $text{'edit_missing'};
		}
	$dbh->commit();
	};
# Release locks and the DBI handle before reporting a failed transaction.
if ($@) {
	my $error = $@;
	eval { $dbh->rollback(); };
	$dbh->disconnect();
	&error(&html_escape($error));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&webmin_log($in{'new'} ? 'create' : 'modify', 'row',
	$object->{'name'}, { 'db' => $path });
&redirect('table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&start='.int($in{'start'} || 0));
