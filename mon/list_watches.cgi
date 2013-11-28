#!/usr/local/bin/perl
# list_watches.cgi

require './mon-lib.pl';
&ui_print_header(undef, $text{'watches_title'}, "");

$conf = &get_mon_config();
@watches = &find("watch", $conf);
if (@watches) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'watches_group'}</b></td> ",
	      "<td><b>$text{'watches_services'}</b></td> </tr>\n";
	foreach $w (@watches) {
		print "<tr $cb>\n";
		print "<td><a href='edit_watch.cgi?idx=$w->{'index'}'>",
		      "$w->{'values'}->[0]</a></td> <td>\n";
		local @servs = &find("service", $w->{'members'});
		foreach $s (@servs) {
			local $i = &find_value("interval", $s->{'members'});
			print "<a href='edit_service.cgi?idx=$w->{'index'}&",
			      "sidx=$s->{'index'}'>$s->{'values'}->[0] ($i)",
			      "</a>&nbsp;|&nbsp;\n";
			}
		print "<a href='edit_service.cgi?idx=$w->{'index'}&new=1'>",
		      "$text{'watches_sadd'}</a></td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'watches_none'}</b><p>\n";
	}
print "<form action=create_watch.cgi>\n";
print "<input type=submit value='$text{'watches_add'}'>\n";
print "<select name=group>\n";
foreach $s (&find("hostgroup", $conf)) {
	print "<option>$s->{'values'}->[0]</option>\n";
	}
print "</select></form>\n";

&ui_print_footer("", $text{'index_return'});

