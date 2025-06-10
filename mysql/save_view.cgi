#!/usr/local/bin/perl
# Create, modify or delete a view

require './mysql-lib.pl';
&ReadParse();
&error_setup($text{'view_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'views'} || &error($text{'view_ecannot'});

if ($in{'delete'}) {
	# Just drop the view
	$sql = "drop view ".&quotestr($in{'old'});
	&execute_sql_logged($in{'db'}, $sql);
	&webmin_log("delete", "view", $in{'old'}, \%in);
	}
else {
	# Validate inputs
	if (!$in{'old'}) {
		$in{'name'} =~ /^\S+$/ || &error($text{'view_ename'});
		@views = &list_views($in{'db'});
		&indexof($in{'name'}, @views) >= 0 &&
			&error($text{'view_eclash'});
		@tables = &list_tables($in{'db'});
		&indexof($in{'name'}, @tables) >= 0 &&
			&error($text{'view_eclash2'});
		}
	$in{'query'} =~ /\S/ || &error($text{'view_equery'});
	$in{'query'} =~ s/\r|\n/ /g;
	$in{'definer_def'} || $in{'definer'} =~ /\S/ ||
		&error($text{'view_edefiner'});

	if ($in{'old'}) {
		# Alter the existing view
		$sql = "alter ".
		       "algorithm = $in{'algorithm'} ".
		       "definer = $in{'definer'} ".
		       "sql security $in{'security'} ".
		       "view ".&quotestr($in{'old'})." ".
		       "as $in{'query'} ".
		       ($in{'check'} ? "with $in{'check'} check option" : "");
		}
	else {
		# Create a new view
		$sql = "create ".
		       "algorithm = $in{'algorithm'} ".
		       ($in{'definer_def'} ? "" : "definer = $in{'definer'} ").
		       ($in{'security'} ? "sql security $in{'security'} " : "").
		       "view ".&quotestr($in{'name'})." ".
		       "as $in{'query'} ".
		       ($in{'check'} ? "with $in{'check'} check option" : "");
		}
	&execute_sql_logged($in{'db'}, $sql);

	if ($in{'old'}) {
		&webmin_log("modify", "view", $in{'old'}, \%in);
		}
	else {
		&webmin_log("create", "view", $in{'name'}, \%in);
		}
	}
&redirect("edit_dbase.cgi?db=$in{'db'}");

