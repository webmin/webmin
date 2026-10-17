#!/usr/local/bin/perl
# Renames a table.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'rename_err'});

# Recheck write access and find the table; SQLite cannot rename a view.
my $path = &sqlite_database_path($in{'db'});
&sqlite_can_write($path) || &error($text{'error_readonly'});
my $dbh = &sqlite_connect($path, 1);
my $object = &sqlite_object($dbh, $in{'table'});
$object && $object->{'type'} eq 'table' || &error($text{'table_missing'});
my $name = $in{'name'};
$name =~ s/^\s+|\s+$//g;
&sqlite_valid_name($name) ||
	&error(&text('create_ename', &html_escape($name)));

# The same name again is not an error, just nothing to do.
if ($name ne $object->{'name'}) {
	# Refuse to take the name of another table or view.
	if (lc($name) ne lc($object->{'name'}) && &sqlite_object($dbh, $name)) {
		$dbh->disconnect();
		&error(&text('create_eexists', &html_escape($name)));
		}
	eval { $dbh->do('ALTER TABLE '.
			&sqlite_quote_identifier($object->{'name'}).
			' RENAME TO '.&sqlite_quote_identifier($name)); };
	# Pass SQLite's own objection through the normal error page.
	if ($@) {
		my $message = $@;
		$dbh->disconnect();
		&error(&html_escape($message));
		}
	&webmin_log('rename', 'table', $object->{'name'},
		{ 'db' => $path, 'name' => $name });
	}
$dbh->disconnect();
&sqlite_adopt_ownership($path);
&redirect('table.cgi?db='.&urlize($path).'&table='.&urlize($name).
	'&view=structure');
