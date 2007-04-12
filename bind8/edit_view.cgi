#!/usr/local/bin/perl
# edit_view.cgi
# Display options for an existing view

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
$view = $conf->[$in{'index'}];
$vconf = $view->{'members'};
$access{'views'} || &error($text{'view_ecannot'});
&can_edit_view($view) || &error($text{'view_ecannot'});

&ui_print_header(undef, $text{'view_title'}, "");

print "<form action=save_view.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'view_opts'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@v = @{$view->{'values'}};
print "<tr> <td><b>$text{'view_name'}</b></td>\n";
print "<td><tt>$v[0]</tt></td>\n";

print "<td><b>$text{'view_class'}</b></td>\n";
printf "<td>%s</td> </tr>\n",
	$v[1] ? "<tt>$v[1]</tt>" : "$text{'default'} (<tt>IN</tt>)";

print "<tr>\n";
print &addr_match_input($text{'view_match'}, "match-clients", $vconf);
print &choice_input($text{'view_recursion'}, 'recursion', $vconf,
		    $text{'yes'}, 'yes', $text{'no'}, 'no',
		    $text{'default'}, undef);
print "</tr>\n";

print "</table></td></tr> </table>\n";
if ($access{'ro'}) {
	print "</form>\n";
	}
else {
	print "<table width=100%><tr><td align=left>\n";
	print "<input type=submit value=\"$text{'save'}\"></td></form>\n";

	print "<form action=delete_view.cgi>\n";
	print "<input type=hidden name=index value=\"$in{'index'}\">\n";
	print "<td align=right><input type=submit ",
	      "value=\"$text{'delete'}\"></td></form>\n";
	print "</tr></table>\n";
	}
&ui_print_footer("", $text{'index_return'});

