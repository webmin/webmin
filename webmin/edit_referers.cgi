#!/usr/local/bin/perl
# edit_referers.cgi
# Display a list of trusted referers

require './webmin-lib.pl';
&ui_print_header(undef, $text{'referers_title'}, "");

print $text{'referers_desc'},"<br>\n";
print "<form action=change_referers.cgi>\n";
print "<table>\n";

print "<tr> <td><b>$text{'referers_referer'}</b></td>\n";
printf "<td><input type=radio name=referer value=0 %s> %s\n",
	$gconfig{'referer'} ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=referer value=1 %s> %s</td> </tr>\n",
	$gconfig{'referer'} ? 'checked' : '', $text{'no'};

print "<tr> <td valign=top><b>$text{'referers_list'}</b></td>\n";
print "<td><textarea name=referers rows=5 cols=30>",
      join("\n", split(/\s+/, $gconfig{'referers'})),"</textarea><br>\n";
printf "<input type=checkbox name=referers_none value=1 %s> %s</td> </tr>\n",
	$gconfig{'referers_none'} ? '' : 'checked', $text{'referers_none'};

print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

