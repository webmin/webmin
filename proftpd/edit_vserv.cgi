#!/usr/local/bin/perl
# edit_vserv.cgi
# Edit <VirtualHost> section details

require './proftpd-lib.pl';
&ReadParse();
$vconf = &get_config()->[$in{'virt'}];
$desc = &text('virt_header1', $vconf->{'value'});
&ui_print_header($desc, $text{'vserv_title'}, "",
	undef, undef, undef, undef, &restart_button());

$name = &find_directive("ServerName", $vconf->{'members'});
$port = &find_directive("Port", $vconf->{'members'});

print "<form action=save_vserv.cgi>\n";
print "<input type=hidden name=virt value=$in{'virt'}>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'vserv_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'vserv_addr'}</b></td>\n";
printf "<td><input name=addr size=30 value='%s'></td> </tr>\n",
	$vconf->{'value'};

print "<tr> <td><b>$text{'vserv_name'}</b></td>\n";
print "<td>",&opt_input($name, "ServerName", $text{'default'}, 30),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'vserv_port'}</b></td>\n";
print "<td>",&opt_input($port, "Port", $text{'default'}, 6),
      "</td> </tr>\n";

print "<tr> <td colspan=2>\n";
print "<input type=submit value=\"$text{'save'}\">\n";
print "<input type=submit value=\"$text{'vserv_delete'}\" name=delete>\n";
print "</td> </tr>\n";

print "</table> </td></tr></table><p>\n";
print "</form>\n";

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

