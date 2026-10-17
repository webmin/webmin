#!/usr/local/bin/perl
# Executes one SQL statement against an SQLite database.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %in, %access);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'exec_err'});
$access{'sql'} || &error($text{'exec_denied'});
$in{'sql'} =~ /\S/ || &error($text{'exec_empty'});

# Match the connection mode to write access and install the SQL sandbox.
my $path = &sqlite_database_path($in{'db'});
my $write = &sqlite_can_sql_write($path);
my $dbh = &sqlite_connect($path, $write ? 1 : 0, 0, $write ? 1 : 0);
&sqlite_install_authorizer($dbh);
my $limit = int($config{'max_query_rows'} || 1000);
# Use one row as the minimum result limit.
$limit = 1 if ($limit < 1);
# Cap SQL results at 100,000 rows.
$limit = 100000 if ($limit > 100000);
# Execute one statement and preserve any DBI exception.
my $result = eval {
	&sqlite_query($dbh, $in{'sql'}, $limit);
	};
# Release the database handle before reporting a failed statement.
if ($@) {
	my $error = $@;
	$dbh->disconnect();
	&error(&html_escape($error));
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);

&ui_print_header(undef, $text{'exec_title'}, '', 'exec');
print &ui_tag('p', &text('exec_result',
	&ui_tag('tt', &html_escape($in{'sql'}))));
# Statements with named columns render a result table.
if (@{$result->{'columns'}}) {
	print &ui_columns_start([ map { &html_escape($_) }
		@{$result->{'columns'}} ], 100, 0, undef, undef, 1);
	foreach my $row (@{$result->{'rows'}}) {
		print &ui_columns_row([ map { &sqlite_display_value($_) } @$row ]);
		}
	print &ui_columns_end();
	# Warn when the configured result cap omitted additional rows.
	print &ui_alert_box(&text('exec_truncated', $limit), 'warn')
		if ($result->{'truncated'});
	}
else {
	# Statements without result columns report their affected-row count.
	print &ui_alert_box(&text('exec_affected',
		$result->{'affected'} < 0 ? 0 : $result->{'affected'}),
		'success', undef, undef, '');
	}
# Log the statement, then offer to run another one.
&webmin_log('exec', 'sql', $path, { 'sql' => $in{'sql'} });
print &ui_form_start('exec_form.cgi');
print &ui_hidden('db', $path);
print &ui_form_end([ [ undef, $text{'exec_again'} ] ]);
&ui_print_footer('database.cgi?db='.&urlize($path),
	$text{'database_return'});
