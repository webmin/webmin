#!/usr/local/bin/perl
# edit_ipnode.cgi
# Edit or create a ipnode address

require './net-lib.pl';
$access{'ipnodes'} == 2 || &error($text{'ipnodes_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'ipnodes_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'ipnodes_edit'}, "");
	@ipnodes = &list_ipnodes();
	$h = $ipnodes[$in{'idx'}];
	}

print "<form action=save_ipnode.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'ipnodes_detail'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'ipnodes_ip'}</b></td>\n";
print "<td><input name=address size=30 value=\"$h->{'address'}\"></td> </tr>\n";
print "<tr $cb> <td valign=top><b>$text{'ipnodes_host'}</b></td>\n";
print "<td><textarea cols=30 rows=5 name=ipnodes>",
	join("\n", @{$h->{'ipnodes'}}),"</textarea></td> </tr>\n";
print "<tr> <td colspan=2 align=right>\n";
if ($in{'new'}) {
	print "<input type=submit value=\"$text{'create'}\">\n";
	}
else {
	print "<input type=submit value=\"$text{'save'}\">\n";
	print "<input type=submit name=delete value=\"$text{'delete'}\">\n";
	}
print "</table></td></tr></table>\n";
print "</form>\n";

&ui_print_footer("list_ipnodes.cgi", $text{'ipnodes_return'});

