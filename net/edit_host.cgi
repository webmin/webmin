#!/usr/local/bin/perl
# edit_host.cgi
# Edit or create a host address

require './net-lib.pl';
$access{'hosts'} == 2 || &error($text{'hosts_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'hosts_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'hosts_edit'}, "");
	@hosts = &list_hosts();
	$h = $hosts[$in{'idx'}];
	}

print "<form action=save_host.cgi>\n";
print "<input type=hidden name=new value=\"$in{'new'}\">\n";
print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'hosts_detail'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'hosts_ip'}</b></td>\n";
print "<td><input name=address size=30 value=\"$h->{'address'}\"></td> </tr>\n";
print "<tr $cb> <td valign=top><b>$text{'hosts_host'}</b></td>\n";
print "<td><textarea cols=30 rows=5 name=hosts>",
	join("\n", @{$h->{'hosts'}}),"</textarea></td> </tr>\n";
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

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'});

