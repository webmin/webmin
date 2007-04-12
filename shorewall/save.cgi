#!/usr/local/bin/perl
# save.cgi
# Updated, modify or delete a table entry

require './shorewall-lib.pl';
&ReadParse();
&can_access($in{'table'}) || &error($text{'list_ecannot'});
$pfunc = $in{'table'}."_parser";
$pfunc = "standard_parser" if (!defined(&$pfunc));
&error_setup($text{$in{'table'}."_err"});

&lock_table($in{'table'});
if ($in{'delete'}) {
	# Just delete one row
	&delete_table_row($in{'table'}, $pfunc, $in{'idx'});
	}
else {
	# Validate inputs
	$vfunc = $in{'table'}."_validate";
	@row = &$vfunc();
	$jfunc = $in{'table'}."_join";
	if (defined(&$jfunc)) {
		$line = &$jfunc(@row);
		}
	else {
		$line = join("\t", @row);
		}

	# Update or add
	if ($in{'new'}) {
		local $where = $in{'before'} ne '' ? $in{'before'} :
			       $in{'after'} ne '' ? $in{'after'}+1 : undef;
		&create_table_row($in{'table'}, $pfunc, $line, $where);
		}
	else {
		# Updating 
		&modify_table_row($in{'table'}, $pfunc, $in{'idx'}, $line);
		}
	}
&unlock_table($in{'table'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "table", $in{'table'});
&redirect("list.cgi?table=$in{'table'}");

