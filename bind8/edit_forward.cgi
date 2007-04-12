#!/usr/local/bin/perl
# edit_forward.cgi
# Display options for an existing forward zone

require './bind8-lib.pl';
&ReadParse();
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$dom = $conf->[$in{'index'}]->{'value'};
&can_edit_zone($conf->[$in{'index'}], $view) ||
	&error($text{'fwd_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'fwd_title'}, "");

print "<form action=save_forward.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'fwd_opts'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &forwarders_input($text{'fwd_masters'}, "forwarders", $zconf);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'fwd_forward'}, "forward", $zconf,
		    $text{'yes'}, "first", $text{'no'}, "only",
		    $text{'default'}, undef);
print &choice_input($text{'fwd_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print "</tr>\n";

print "</table></td></tr> </table>\n";

if ($access{'ro'}) {
	print "</form>\n";
	}
else {
	print "<table width=100%><tr><td align=left>\n";
	print "<input type=submit value=\"$text{'save'}\"></td></form>\n";

	@views = &find("view", $bconf);
	if ($in{'view'} eq '' && @views || $in{'view'} ne '' && @views > 1) {
		print "<form action=move_zone.cgi>\n";
		print "<input type=hidden name=index value=\"$in{'index'}\">\n";
		print "<input type=hidden name=view value=\"$in{'view'}\">\n";
		print "<td width=33% align=middle>\n";
		print "<input type=submit value=\"$text{'master_move'}\">\n";
		print "<select name=newview>\n";
		foreach $v (@views) {
			printf "<option value=%d>%s\n",
			    $v->{'index'}, $v->{'value'}
				if ($v->{'index'} ne $in{'view'});
			}
		print "</select></td></form>\n";
		}
	else {
		print "<td></td>\n";
		}

	print "<form action=delete_zone.cgi>\n";
	print "<input type=hidden name=index value=\"$in{'index'}\">\n";
	print "<input type=hidden name=view value=\"$in{'view'}\">\n";
	print "<td align=right><input type=submit ",
	      "value=\"$text{'delete'}\"></td></form>\n";
	print "</tr></table>\n";
	}
&ui_print_footer("", $text{'index_return'});

