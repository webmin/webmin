#!/usr/local/bin/perl
# download.cgi
# Output the contents of a blob field

if (-r 'mysql-lib.pl') {
	require './mysql-lib.pl';
	}
else {
	require './postgresql-lib.pl';
	}

&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
@str = &table_structure($in{'db'}, $in{'table'});

# Get search and limiting SQL
($search, $searchhids, $searchargs) = &get_search_args(\%in);
$limitsql = &get_search_limit(\%in);
($sortsql, $sorthids, $sortargs) = &get_search_sort(\%in);

$d = &execute_sql($in{'db'},
	"select * from ".&quote_table($in{'table'})." $search $sortsql $limitsql");

# Work out the MIME type based on the data
$data = $d->{'data'}->[$in{'row'}]->[$in{'col'}];
if ($data =~ /^\s*(<!doctype|<html|<head|<title)/i) {
	$type = "text/html";
	}
elsif ($data =~ /^GIF89/) {
	$type = "image/gif";
	}
elsif ($data =~ /^\377\330\377\340/) {
	$type = "image/jpeg";
	}
elsif ($data =~ /^%PDF/) {
	$type = "application/pdf";
	}
elsif ($data =~ /^[\040-\176\r\n\t]+$/) {
	$type = "text/plain";
	}
else {
	$type = "application/octet-stream";
	}
print "Content-type: $type\n\n";
print $data;

