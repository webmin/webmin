#!/usr/local/bin/perl
# edit_hint.cgi
# Display information about the hint (root) zone

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'hint_ecannot'});

&ui_print_header(undef, $text{'hint_title'}, "");

print $text{'hint_desc'},"<p>\n";

print "<table width=100%> <tr>\n";

# Re-fetch master file button
print "<form action=refetch.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<td width=50%><input type=submit ",
      "value=\"$text{'hint_refetch'}\"></td></form>\n";

# Delete button
print "<form action=delete_zone.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<td align=right width=50%><input type=submit ",
      "value=\"$text{'delete'}\"></td></form>\n";
print "</tr></table>\n";

&ui_print_footer("", $text{'index_return'});

