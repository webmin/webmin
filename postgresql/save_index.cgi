#!/usr/local/bin/perl
# Create, re-create or delete an index

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'index_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'indexes'} || &error($text{'index_ecannot'});

if ($in{'delete'}) {
	# Just drop the index
	$sql = "drop index ".&quote_table($in{'old'});
	&execute_sql_logged($in{'db'}, $sql);
	&webmin_log("delete", "index", $in{'old'}, \%in);
	}
else {
	# Validate inputs
	$in{'name'} =~ /^\S+$/ || &error($text{'index_ename'});
	if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
		@indexes = &list_indexes($in{'db'});
		&indexof($in{'name'}, @indexes) >= 0 &&
			&error($text{'index_eclash'});
		}
	@cols = split(/\0/, $in{'cols'});
	@cols || &error($text{'index_ecols'});
	if ($in{'type'} eq 'unique' && $in{'using'} ne 'btree') {
		&error($text{'index_ehash'});
		}

	# Do it
	if ($in{'old'}) {
		# Remove the old one first
		$sql = "drop index ".&quote_table($in{'old'});
		&execute_sql_logged($in{'db'}, $sql);
		}
	$sql = "create $in{'type'} index ".&quotestr($in{'name'})." on ".
	       &quote_table($in{'table'})." using ".&quotestr($in{'using'}).
	       " (".join(", ", map { &quotestr($_) } @cols).")";
	&execute_sql_logged($in{'db'}, $sql);

	if ($in{'old'}) {
		&webmin_log("modify", "index", $in{'old'}, \%in);
		}
	else {
		&webmin_log("create", "index", $in{'name'}, \%in);
		}
	}
&redirect("edit_dbase.cgi?db=$in{'db'}");

