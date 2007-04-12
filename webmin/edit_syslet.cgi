#!/usr/local/bin/perl
# edit_syslet.cgi
# Configure the automatic download and install of Eazel syslets

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'syslet_title'}, "");

print $text{'syslet_desc'},"<br>\n";
print "<form action=change_syslet.cgi>\n";
print "<table>\n";

&get_miniserv_config(\%miniserv);
$auto = ($miniserv{'error_handler_404'} eq '/eazel_download_module.cgi');
print "<tr> <td><b>$text{'syslet_auto'}</b></td>\n";
printf "<td><input type=radio name=auto value=1 %s> %s\n",
	$auto ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=auto value=0 %s> %s</td> </tr>\n",
	$auto ? '' : 'checked', $text{'no'};

print "<tr> <td valign=top><b>$text{'syslet_base'}</b></td>\n";
print "<td><textarea name=syslet_base rows=4 cols=40>",
	join("\n", split(/\s+/, $gconfig{'syslet_base'})),
	"</textarea></td> </tr>\n";

print "</table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";
&ui_print_footer("", $text{'index_return'});

