#!/usr/local/bin/perl
# view_form.cgi
# Display options for creating a new view

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
$access{'views'} == 1 || &error($text{'vcreate_ecannot'});
$access{'ro'} && &error($text{'vcreate_ecannot'});

&ui_print_header(undef, $text{'vcreate_title'}, "");

print "<form action=create_view.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'view_opts'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'view_name'}</b></td>\n";
print "<td><input name=name size=25></td>\n";

print "<td><b>$text{'view_class'}</b></td>\n";
print "<td><input type=radio name=class_def value=1 checked> ",
      "$text{'default'}\n";
print "<input type=radio name=class_def value=0>\n";
print "<input name=class size=4></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'view_match'}</b></td> <td colspan=3>\n";
print "<input type=radio name=match_def value=1> $text{'vcreate_match_all'}\n";
print "<input type=radio name=match_def value=0 checked> ",
      "$text{'vcreate_match_sel'}<br>\n";
print "<textarea name=match rows=5 cols=40></textarea></td> </tr>\n";

print "</table></td></tr> </table>\n";
print "<input type=submit value=\"$text{'create'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

