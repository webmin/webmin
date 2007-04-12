#!/usr/local/bin/perl
# drop_field.cgi
# Drop a field from some table

sub mytext($);

require './postgresql-lib.pl';
&ReadParse();
&can_edit_db($in{'db'}) || &error(mytext('dbase_ecannot'));

$desc = &text('table_header', "<tt>$in{'table'}</tt>", "<tt>$in{'db'}</tt>");
&ui_print_header($desc, mytext('fdrop_title'), "", "field_drop");

@desc = &table_structure($in{'db'}, $in{'table'});

local $table_shuffle;
# If a field drop has been specified using this script
if ( $in{'dropfld'} && $in{'dropfldok'} ) {

	# Drop the field by copying the other fields through a temp table
	&error_setup(mytext('fdrop_err'));

	local $i;
	local $fld_list = "";

	if( @desc > 1 ) {
		for($i=0; $i<scalar(@desc); $i++) {
			local $r = $desc[$i];
			if( $in{'dropfld'} ne &html_escape($r->{'field'}) ) {
				# Note PostgreSQL requires quotes for uppercase
				if( $fld_list eq "" ) {
					$fld_list = '"'.$r->{'field'}.'"';
				} else {
					$fld_list = $fld_list . ', "' .$r->{'field'}.'"';
				}
			}
		}
	}
	
	if( $fld_list ne "" ) {
		local $tmp_tbl = "webmin_tmp_table".$PROCESS_ID;
		local $qt = &quote_table($in{'table'});
		$table_shuffle = join '',
			"LOCK TABLE $qt;",
			"CREATE TABLE $tmp_tbl AS SELECT $fld_list FROM $qt;",
			"DROP TABLE $qt;",
			"ALTER TABLE $tmp_tbl RENAME TO $qt;";
			
  		&execute_sql_logged($in{'db'}, $table_shuffle);

		&webmin_log("delete", "table+field", $in{'table'}."+".$in{'dropfld'}, \%in);
	}

	@desc = &table_structure($in{'db'}, $in{'table'});

}  # if a field drop has been specified

# Display field selection screen

$mid = int((@desc / 2)+0.5);
print "<form action=drop_field.cgi>\n";
print "<input type=hidden name=db value='$in{'db'}'>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<table border=0 width=100%> <tr><td valign=top width=50%>\n";
&type_table(0, $mid);
print "</td><td valign=top width=50%>\n";
&type_table($mid, scalar(@desc)) if (@desc > 1);
print "</td></tr> </table>\n";

print "<table width=100%><tr>\n";

print "<td>\n";
print "<input type=checkbox name=dropfldok",
	" value=dropit>",
	&html_escape(mytext('fdrop_lose_data')),
	"</option>",
	"</td>\n";
print "<td align=right width=33%>\n";
print '<input type=submit name="drop_a_fld" value="',
	mytext('fdrop_perform').'"></td>'."\n";

print "</tr></table>\n";
print "</form>\n";

&ui_print_footer("edit_table.cgi?db=$in{'db'}&table=$in{'table'}",mytext('table_return'),
	"edit_dbase.cgi?db=$in{'db'}", mytext('dbase_return'),
	"", mytext('index_return'));

sub type_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td><b>".mytext('table_field')."</b></td> ",
      "<td><b>".mytext('table_type')."</b></td> ",
      "<td><b>".mytext('table_arr')."</b></td> ",
      "<td><b>".mytext('fdrop_header')."</b></td> </tr>\n";
local $i;
for($i=$_[0]; $i<$_[1]; $i++) {
	local $r = $desc[$i];
	print "<tr $cb>\n";
	print "<td><a href='edit_field.cgi?db=$in{'db'}&table=$in{'table'}&",
	      "idx=$i'>",&html_escape($r->{'field'}),"</a></td>\n";
	print "<td>",&html_escape($r->{'type'}),"</td>\n";
	print "<td>",$r->{'arr'} eq 'YES' ? mytext('yes')
					  : mytext('no'),"</td>\n";
	print "<td>","<input type=radio name=dropfld value='",
		&html_escape($r->{'field'}),"' ></td>\n";
	print "</tr>\n";
	}
print "</table>\n";
}

sub mytext($)
{
	my ($x) = @_;
	my $rv = $text{"$x"};
	if( ! $rv ) {
		$rv = "$x";	# if unknown text, use the label
	}
	return $rv;
}
