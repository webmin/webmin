#!/usr/local/bin/perl
# save_field.cgi
# Create or rename a field

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});

$qt = &quote_table($in{'table'});
if ($in{'delete'}) {
	# Attempt to remove field
	&error_setup($text{'field_err1'});
	&execute_sql_logged($in{'db'}, "alter table $qt ".
			       "drop column \"$in{'old'}\"");
	}
else {
	# Validate inputs
	&error_setup($text{'field_err2'});
	$in{'field'} =~ /^\S+$/ || &error(&text('field_efield', $in{'field'}));
	if ($in{'new'}) {
		# Add field
		if (defined($in{'size'})) {
			$in{'size'} =~ /^\d+(,\d+)?$/ ||
				&error(&text('field_esize', $in{'size'}));
			$size = "($in{'size'})";
			}
		$arr = $in{'arr'} ? "[]" : "";
		&execute_sql_logged($in{'db'}, "alter table $qt add ".
				       "\"$in{'field'}\" $in{'type'}$size$arr");
		}
	elsif ($in{'old'} ne $in{'field'}) {
		# Rename field
		&execute_sql_logged($in{'db'}, "alter table $qt rename ".
				       "\"$in{'old'}\" to \"$in{'field'}\"");
		}
	}
&redirect("edit_table.cgi?db=$in{'db'}&table=$in{'table'}");

