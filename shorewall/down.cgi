#!/usr/bin/perl
# down.cgi
# Move a row in a table down

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
$pfunc = &get_parser_func(\%in);
&lock_table($in{'table'});
&swap_table_rows($in{'table'}, $pfunc, $in{'idx'}, $in{'idx'}+1);
&unlock_table($in{'table'});
&webmin_log('down', 'table', $in{'table'});
&redirect("list.cgi?table=$in{'table'}");

