#!/usr/local/bin/perl
# edit_ips.cgi
# Edit which addresses are allowed or denied for connection to the server

require './jabber-lib.pl';
&ui_print_header(undef, $text{'ips_title'}, "", "ips");

$conf = &get_jabber_config();
$io = &find("io", $conf);
@allow = &find("allow", $io);
@deny = &find("deny", $io);

print "<form action=save_ips.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'ips_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'ips_allow'}</b></td> ",
      "<td><b>$text{'ips_deny'}</b></td> </tr>\n";

printf "<tr> <td><input type=radio name=allow_def value=1 %s> %s\n",
	@allow ? "" : "checked", $text{'ips_all'};
printf "<input type=radio name=allow_def value=0 %s> %s<br>\n",
	@allow ? "checked" : "", $text{'ips_sel'};
print "<textarea name=allow rows=8 cols=30>\n";
foreach $a (@allow) {
	local $ip = &find_value("ip", $a), $nm = &find_value("mask", $a);
	if ($nm) { print "$ip/$nm\n"; }
	else { print "$ip\n"; }
	}
print "</textarea></td>\n";

printf "<td><input type=radio name=deny_def value=1 %s> %s\n",
	@deny ? "" : "checked", $text{'ips_none'};
printf "<input type=radio name=deny_def value=0 %s> %s<br>\n",
	@deny ? "checked" : "", $text{'ips_sel'};
print "<textarea name=deny rows=8 cols=30>\n";
foreach $a (@deny) {
	local $ip = &find_value("ip", $a), $nm = &find_value("mask", $a);
	if ($nm) { print "$ip/$nm\n"; }
	else { print "$ip\n"; }
	}
print "</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

