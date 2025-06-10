#!/usr/local/bin/perl
# Create, modify or delete a sequence

require './postgresql-lib.pl';
&ReadParse();
&error_setup($text{'seq_err'});
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
$access{'seqs'} || &error($text{'seq_ecannot'});

if ($in{'delete'}) {
	# Just drop the sequence
	$sql = "drop sequence ".&quote_table($in{'old'});
	&execute_sql_logged($in{'db'}, $sql);
	&webmin_log("delete", "seq", $in{'old'}, \%in);
	}
else {
	# Validate inputs
	$in{'old'} || $in{'name'} =~ /^\S+$/ || &error($text{'seq_ename'});
	if (!$in{'old'}) {
		@seqs = &list_sequences($in{'db'});
		&indexof($in{'name'}, @seqs) >= 0 &&
			&error($text{'seq_eclash'});
		}
	$in{'min_def'} || $in{'min'} =~ /^\d+$/ ||
		&error($text{'seq_emin'});
	$in{'max_def'} || $in{'max'} =~ /^\d+$/ ||
		&error($text{'seq_emax'});
	$in{'inc'} =~ /^\d+$/ || &error($text{'seq_einc'});
	$in{'cache_def'} || $in{'cache'} =~ /^\d+$/ ||
		&error($text{'seq_ecache'});

	if (&supports_sequences() == 2 && $in{'old'}) {
		# Need to drop and re-create
		if (&indexof($in{'old'}, &list_sequences($in{'db'})) >= 0) {
			$sql = "drop sequence ".&quote_table($in{'old'});
			&execute_sql_logged($in{'db'}, $sql);
			}
		$sql = "create sequence ".&quote_table($in{'old'}).
		       " increment ".$in{'inc'}.
		       ($in{'min_def'} ? "" : " minvalue ".$in{'min'}).
		       ($in{'max_def'} ? "" : " maxvalue ".$in{'max'}).
		       " start ".$in{'last'}.
		       ($in{'cache_def'} ? "" : " cache ".$in{'cache'}).
		       ($in{'cycle'} ? " cycle" : "");
		}
	elsif ($in{'old'} && !$recreate) {
		# Alter the current sequence
		$sql = "alter sequence ".&quote_table($in{'old'}).
		       " increment ".$in{'inc'}.
		       ($in{'min_def'} ? " no minvalue"
				       : " minvalue ".$in{'min'}).
		       ($in{'max_def'} ? " no maxvalue"
				       : " maxvalue ".$in{'max'}).
		       ($in{'last_def'} ? "" : " restart ".$in{'last'}).
		       " cache ".$in{'cache'}.
		       ($in{'cycle'} ? " cycle" : " no cycle");
		}
	else {
		# Create a new one
		$sql = "create sequence ".&quote_table($in{'name'}).
		       " increment ".$in{'inc'}.
		       ($in{'min_def'} ? "" : " minvalue ".$in{'min'}).
		       ($in{'max_def'} ? "" : " maxvalue ".$in{'max'}).
		       " start ".$in{'last'}.
		       ($in{'cache_def'} ? "" : " cache ".$in{'cache'}).
		       ($in{'cycle'} ? " cycle" : "");
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

