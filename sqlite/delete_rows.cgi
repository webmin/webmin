#!/usr/local/bin/perl
# Confirms and deletes selected SQLite table rows.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});

# Validate the path and require at least one row token.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my @tokens = split(/\0/, $in{'row'});
@tokens || &error($text{'delete_none'});

# Ask for confirmation when configured.
if (!$in{'confirm'} && $config{'confirm_delete'}) {
	&ui_print_header(undef, $text{'delete_title'}, '', 'delete_rows');
	print &ui_confirmation_form('delete_rows.cgi',
		&text('delete_confirm', scalar(@tokens)),
		[ [ 'db', $path ], [ 'table', $in{'table'} ],
		  [ 'start', int($in{'start'} || 0) ],
		  map { [ 'row', $_ ] } @tokens ],
		[ [ 'confirm', $text{'delete_ok'} ] ]);
	&ui_print_footer('table.cgi?db='.&urlize($path).'&table='.
		&urlize($in{'table'}), $text{'table_return'});
	exit;
	}

# Reload the schema before decoding row identities.
my $dbh = &sqlite_connect($path, 1);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $columns = &sqlite_table_columns($dbh, $object->{'name'});
my $identity = &sqlite_identity($dbh, $object, $columns);
$identity || &error($text{'table_noidentity'});
my $count = $identity->{'rowid'} ? 1 : scalar(@{$identity->{'columns'}});

# Decode and delete all selected rows in one transaction.
eval {
	$dbh->begin_work();
	foreach my $token (@tokens) {
		my @keys = &sqlite_decode_key($token, $count);
		my ($where, @params) = &sqlite_identity_where($identity, \@keys);
		$dbh->do('DELETE FROM '.
			&sqlite_quote_identifier($object->{'name'}).
			' WHERE '.$where, undef, @params);
		}
	$dbh->commit();
	};
# Roll back all deletions if any token or delete fails.
if ($@) {
	my $error = $@;
	eval { $dbh->rollback(); };
	$dbh->disconnect();
	&error(&html_escape($error));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&webmin_log('delete', 'rows', scalar(@tokens),
	{ 'db' => $path, 'table' => $object->{'name'} });
&redirect('table.cgi?db='.&urlize($path).'&table='.
	&urlize($object->{'name'}).'&start='.int($in{'start'} || 0));
