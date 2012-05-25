#!/usr/bin/perl
# edit.cgi
# Display a form for editing or creating a table entry

require './shorewall6-lib.pl';
&ReadParse();
&get_clean_table_name(\%in);
&can_access($in{'table'}) || &error($text{'list_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{$in{'tableclean'}."_create"}, "");
	if ($in{'before'} ne '') {
		$msg = &text('edit_before', $in{'before'}+1);
		}
	elsif ($in{'after'} ne '') {
		$msg = &text('edit_after', $in{'after'}+1);
		}
	print "<center><font size=+1>$msg</font></center>\n" if ($msg);
	}
else {
	&ui_print_header(undef, $text{$in{'tableclean'}."_edit"}, "");
	$pfunc = &get_parser_func(\%in);
	@table = &read_table_file($in{'table'}, $pfunc);
	$row = $table[$in{'idx'}];
	}

print "<form action=save.cgi>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=before value='$in{'before'}'>\n";
print "<input type=hidden name=after value='$in{'after'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>",$text{$in{'tableclean'}."_header"},"</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$ffunc = $in{'tableclean'}."_form";
&$ffunc(@$row);

print "</table></td></tr></table>\n";
print "<table width=100%>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</table>\n";

print "</form>\n";

&ui_print_footer("list.cgi?table=$in{'table'}", $text{$in{'tableclean'}."_return"});

