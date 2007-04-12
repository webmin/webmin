#!/usr/local/bin/perl
# up.cgi
# Move a row in a table up

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});

$pfunc = $in{'table'}."_parser";
$pfunc = "standard_parser" if (!defined(&$pfunc));
&lock_table($in{'table'});
&swap_table_rows($in{'table'}, $pfunc, $in{'idx'}, $in{'idx'}-1);
&unlock_table($in{'table'});
&webmin_log('up', 'table', $in{'table'});
&redirect("list.cgi?table=$in{'table'}");

