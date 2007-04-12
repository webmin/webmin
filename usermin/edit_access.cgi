#!/usr/local/bin/perl
# edit_access.cgi
# Display IP access control form

require './usermin-lib.pl';
$access{'access'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'access_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'access_desc'},"<p>\n";

print "<form action=change_access.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$webmin::text{'access_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table><tr><td valign=top nowrap>\n";
printf "<input type=radio name=access value=0 %s>\n",
	$miniserv{"allow"} || $miniserv{"deny"} ? "" : "checked";
print "$webmin::text{'access_all'}<br>\n";
printf "<input type=radio name=access value=1 %s>\n",
	$miniserv{"allow"} ? "checked" : "";
print "$webmin::text{'access_allow'}<br>\n";
printf "<input type=radio name=access value=2 %s>\n",
	$miniserv{"deny"} ? "checked" : "";
print "$webmin::text{'access_deny'}<br>\n";
print "</td> <td valign=top>\n";
printf "<textarea name=ip rows=6 cols=30>%s</textarea></td> </tr>\n",
	$miniserv{"allow"} ? join("\n", split(/\s+/, $miniserv{"allow"})) :
	$miniserv{"deny"} ? join("\n", split(/\s+/, $miniserv{"deny"})) : "";

print "<tr> <td colspan=2>\n";
printf "<input type=checkbox name=alwaysresolve value=1 %s> %s</td> </tr>\n",
	$miniserv{'alwaysresolve'} ? 'checked' : '', $webmin::text{'access_always'};

eval "use Authen::Libwrap qw(hosts_ctl STRING_UNKNOWN)";
if (!$@) {
	print "<tr> <td colspan=2>\n";
	printf "<input type=checkbox name=libwrap value=1 %s> %s</td> </tr>\n",
		$miniserv{'libwrap'} ? 'checked' : '', $webmin::text{'access_libwrap'};
	}

print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

