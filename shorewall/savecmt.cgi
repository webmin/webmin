#!/usr/bin/perl
# Updated, modify or delete a comment

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
$pfunc = &get_parser_func(\%in);
&error_setup($text{"comment_err"});

&lock_table($in{'table'});
if ($in{'delete'}) {
	# Just delete one row
	&delete_table_row($in{'table'}, $pfunc, $in{'idx'});
	}
else {
	# Validate inputs
	$in{'msg'} =~ /\S/ || &error($text{'comment_enone'});
	$line = (&version_atleast(4, 5, 11) ? "?" : "") . "COMMENT $in{'msg'}";

	# Update or add
	if ($in{'new'}) {
		&create_table_row($in{'table'}, $pfunc, $line);
		}
	else {
		# Updating
		&modify_table_row($in{'table'}, $pfunc, $in{'idx'}, $line);
		}
	}
&unlock_table($in{'table'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "comment", $in{'table'});
&redirect("list.cgi?table=$in{'table'}");
