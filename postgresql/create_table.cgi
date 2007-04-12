#!/usr/local/bin/perl
# create_table.cgi
# Create a new table

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&error_setup($text{'table_err'});
$in{'name'} =~ /^\S+$/ || &error($text{'table_ename'});
for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"field_$i"} =~ /^\S+$/ ||
		&error(&text('table_efield', $in{"field_$i"}));
	$in{"type_$i"} || &error(&text('table_etype', $in{"field_$i"}));
	if ($in{"size_$i"}) {
		if (&is_blob({ 'type' => $in{"type_$i"} })) {
			&error(&text('table_eblob', $in{"field_$i"}));
			}
		$f = sprintf "\"%s\" %s(%s)",
		     $in{"field_$i"}, $in{"type_$i"}, $in{"size_$i"};
		}
	else {
		$f = sprintf "\"%s\" %s", $in{"field_$i"}, $in{"type_$i"};
		}
	if ($in{"arr_$i"}) { $f .= "[]"; }
	if (!$in{"null_$i"}) { $f .= " not null"; }
	if ($in{"key_$i"}) { $f .= " primary key"; }
	if ($in{"uniq_$i"}) { $f .= " unique"; }
	push(@fields, $f);
	}
@fields || &error($text{'table_enone'});
$qt = &quote_table($in{'name'});
$sql = "create table $qt (".join(",", @fields).")";
&execute_sql_logged($in{'db'}, $sql);
&webmin_log("create", "table", $in{'name'}, \%in);
&redirect("edit_dbase.cgi?db=$in{'db'}");


