#!/usr/local/bin/perl
# edit_host.cgi
# Show details of a managed host and it's current cfengine configuration

require './cfengine-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&ReadParse();

@hosts = &list_cfengine_hosts();
($host) = grep { $_->{'id'} eq $in{'id'} } @hosts;
$server = &foreign_call("servers", "get_server", $in{'id'});
&remote_foreign_require($server->{'host'}, "cfengine", "cfengine-lib.pl");
&ui_print_header(undef, $text{'host_title'}, "", "edit_host");

# Show host details and current config
print "<form action=delete_host.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'host_name'}</b></td>\n";
if ($server->{'id'}) {
	printf &ui_link("/servers/link.cgi/%s/","%s")."</td>\n",
		$server->{'id'}, $server->{'desc'} ? "$server->{'desc'} ($server->{'host'}:$server->{'port'})" : "$server->{'host'}:$server->{'port'}";
	}
else {
	print "<td><a href=/>$text{'this_server'}</a></td>\n";
	}

if ($server->{'id'}) {
	print "<td><b>$text{'host_type'}</b></td> <td>\n";
	foreach $t (@servers::server_types) {
		print $t->[1] if ($t->[0] eq $server->{'type'});
		}
	print "</td>\n";
	}
print "</tr>\n";

$ver = &cfengine_host_version($server);
print "<tr> <td><b>$text{'host_ver'}</b></td>\n";
print "<td>$ver</td>\n";

print "<td><b>$text{'host_os'}</b></td>\n";
print "<td>$host->{'real_os_type'} $host->{'real_os_version'}</td> </tr>\n";

$rconfig = &remote_foreign_call($server->{'host'}, "cfengine", "get_config");
print "<tr> <td colspan=4><hr><b>",
	&text('host_cfg', &server_name($server)),"</b><p>\n";
&show_classes_table($rconfig, 0, 1);
print "</td> </tr>\n";

print "</table></td></tr></table><br>\n";
print "<input type=submit value='$text{'host_delete'}'></form>\n";

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'});

