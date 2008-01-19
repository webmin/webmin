#!/usr/local/bin/perl
# create_table.cgi
# Create a new table

require './mysql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'table_err'});
$in{'name'} =~ /^\S+$/ || &error($text{'table_ename'});
if ($in{'copy'} || $in{'copytable'}) {
	local ($db, $table) = $in{'copy'} ? split(/\./, $in{'copy'})
					  : ($in{'copydb'}, $in{'copytable'});
	foreach $f (&table_structure($db, $table)) {
		local $copy = &quotestr($f->{'field'})." $f->{'type'}";
		$copy .= " not null" if (!$f->{'null'});
		if ($f->{'key'} eq 'PRI') {
			$copy .= " primary key";
			}
		$copy .= " default '$f->{'default'}'"
			if ($f->{'default'} ne '' && $f->{'default'} ne 'NULL');
		$copy .= " $f->{'extra'}" if ($f->{'extra'});
		push(@fields, $copy);
		}
	}
@sql = &parse_table_form(\@fields, $in{'name'});
foreach $sql (@sql) {
	&execute_sql_logged($in{'db'}, $sql);
	}
&webmin_log("create", "table", $in{'name'}, \%in);
&redirect("edit_dbase.cgi?db=$in{'db'}");


