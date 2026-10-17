#!/usr/local/bin/perl
# Validates and opens an SQLite database path.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access);
require './sqlite-lib.pl';
&ReadParse();
&error_setup($text{'open_err'});

my $requested = $in{'db'};
# Check the ACL, then open the file to verify the database. A missing file
# is created when the ACL allows this user to create and fill one.
my $path = &sqlite_database_path($requested, &sqlite_can_create());
my $creating = !-e $path;
my $dbh = &sqlite_connect($path, $creating ? 1 : 0, $creating ? 1 : 0);
$dbh->disconnect();
# Give a new file to the non-root owner of its parent directory.
# Opening an existing database makes no change and therefore is not logged.
if ($creating) {
	my ($parent) = $path =~ m!^(.*)/[^/]+$!;
	$parent = '/' if ($parent eq '');
	my @pst = stat($parent);
	&sqlite_safe_chown($path, $pst[4], $pst[5])
		if (@pst && $pst[4] != 0 && $< == 0);
	&sqlite_adopt_ownership($path);
	&webmin_log('create', 'database', $path);
	}
&redirect('database.cgi?db='.&urlize($path));
