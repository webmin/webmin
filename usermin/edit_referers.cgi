#!/usr/local/bin/perl
# edit_referers.cgi
# Display a list of trusted referers

require './usermin-lib.pl';
&ui_print_header(undef, $webmin::text{'referers_title'}, "");
&get_usermin_config(\%ugconfig);

print $text{'referers_desc'},"<br>\n";
print "<form action=change_referers.cgi>\n";
print "<table>\n";

print "<tr> <td><b>$webmin::text{'referers_referer'}</b></td>\n";
printf "<td><input type=radio name=referer value=0 %s> %s\n",
	$ugconfig{'referer'} ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=referer value=1 %s> %s</td> </tr>\n",
	$ugconfig{'referer'} ? 'checked' : '', $text{'no'};

print "<tr> <td valign=top><b>$webmin::text{'referers_list'}</b></td>\n";
print "<td><textarea name=referers rows=5 cols=30>",
      join("\n", split(/\s+/, $ugconfig{'referers'})),"</textarea><br>\n";
printf "<input type=checkbox name=referers_none value=1 %s> %s</td> </tr>\n",
	$ugconfig{'referers_none'} ? '' : 'checked',
	$webmin::text{'referers_none'};

print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

