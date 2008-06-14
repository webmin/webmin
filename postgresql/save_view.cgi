#!/usr/local/bin/perl
# Create, re-create or delete a view

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'view_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'views'} || &error($text{'view_ecannot'});

if ($in{'delete'}) {
	# Just drop the view
	$sql = "drop view ".&quote_table($in{'old'});
	&execute_sql_logged($in{'db'}, $sql);
	&webmin_log("delete", "view", $in{'old'}, \%in);
	}
else {
	# Validate inputs
	$in{'name'} =~ /^\S+$/ || &error($text{'view_ename'});
	if (!$in{'old'} || $in{'old'} ne $in{'name'}) {
		@views = &list_views($in{'db'});
		&indexof($in{'name'}, @views) >= 0 &&
			&error($text{'view_eclash'});
		}
	$in{'query'} =~ /\S/ || &error($text{'view_equery'});
	$in{'query'} =~ s/\r|\n/ /g;
	if ($in{'cols_set'}) {
		$cols = join(",", split(/\s+/, $in{'cols'}));
		$cols || &error($text{'view_ecols'});
		}

	# Do it
	if ($in{'old'}) {
		# Remove the old one first
		$sql = "drop view ".&quote_table($in{'old'});
		&execute_sql_logged($in{'db'}, $sql);
		}
	$sql = "create view ".&quote_table($in{'name'}).
	       ($cols ? " (".$cols.")" : "")." as ".$in{'query'};
	&execute_sql_logged($in{'db'}, $sql);

	if ($in{'old'}) {
		&webmin_log("modify", "view", $in{'old'}, \%in);
		}
	else {
		&webmin_log("create", "view", $in{'name'}, \%in);
		}
	}
&redirect("edit_dbase.cgi?db=$in{'db'}");

