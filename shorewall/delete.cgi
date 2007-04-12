#!/usr/local/bin/perl
# Delete a bunch of table rows

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
$pfunc = $in{'table'}."_parser";
$pfunc = "standard_parser" if (!defined(&$pfunc));
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
scalar(@d) || &error($text{'delete_enone'});

&lock_table($in{'table'});
foreach $idx (sort { $b <=> $a } @d) {
	&delete_table_row($in{'table'}, $pfunc, $idx);
	}
&unlock_table($in{'table'});
&webmin_log('deletes', 'table', $in{'table'});
&redirect("list.cgi?table=$in{'table'}");

