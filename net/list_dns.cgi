#!/usr/local/bin/perl
# list_dns.cgi
# Display the DNS client configuration

require './net-lib.pl';
$access{'dns'} || &error($text{'dns_ecannot'});
&ui_print_header(undef, $text{'dns_title'}, "");

$dns = &get_dns_config();
print "<form action=save_dns.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'dns_options'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'dns_hostname'}</b></td>\n";
printf "<td><input name=hostname size=20 value=\"%s\"></td>\n",
	&get_hostname();

$order = &order_input($dns);
if ($order) {
	print "<td><b>$text{'dns_order'}</b></td>\n";
	print "<td>$order</td> </tr>\n";
	}

# Find hostname in /etc/hosts
@hosts = &list_hosts();
foreach $h (@hosts) {
	foreach $n (@{$h->{'hosts'}}) {
		$found++ if ($n eq &get_hostname());
		}
	}
if ($found) {
	print "<tr> <td></td>\n";
	print "<td colspan=3><input type=checkbox name=hosts value=1 checked> ",
	      "$text{'dns_hoststoo'}</td> </tr>\n";
	}

# Check if hostname is set from DHCP
# XXX not done yet
#$dhost = defined(&get_dhcp_hostname) ? &get_dhcp_hostname() : -1;
#if ($dhost != -1) {
#	print "<tr> <td></td>\n";
#	print "<td>",&ui_checkbox("dhcp", 1, $text{'dns_dhcp'}, $dhost),
#	      "</td> </tr>\n";
#	}

print "<tr> <td valign=top><b>";
print "$dns->{'name'}[0] " if $dns->{'name'};
print "$text{'dns_servers'}</b></td> <td valign=top>\n";
print "<input type=hidden name=name0 value=\"$dns->{'name'}[0]\">\n"
    if $dns->{'name'};
for($i=0; $i<$max_dns_servers || $i<@{$dns->{'nameserver'}}+1; $i++) {
	printf "<input name=nameserver_$i size=15 value=\"%s\"><br>\n",
		$dns->{'nameserver'}->[$i];
	}
print "</td>\n";

if (@{$dns->{'name'}} > 1) {
    for ($j=1; $j<@{$dns->{'name'}}; $j++) {
	print "<td valign=top><b>";
	print "$dns->{'name'}[$j] ";
	print "$text{'dns_servers'}</b></td> <td valign=top>\n";
	print "<input type=hidden name=name$j value=\"$dns->{'name'}[$j]\">\n";
	for ($i=0; $i<$max_dns_servers; $i++) {
	    printf "<input name=nameserver${j}_$i size=15 value=\"%s\"><br>\n",
		$dns->{"nameserver$j"}->[$i];
	}
	print "</td>\n";
    }
}

print "<td valign=top><b>$text{'dns_search'}</b></td> <td valign=top>\n";
printf "<input type=radio name=domain_def value=1 %s> $text{'dns_none'}\n",
	$dns->{'domain'} ? "" : "checked";
printf "<input type=radio name=domain_def value=0 %s> $text{'dns_listed'}\n",
	$dns->{'domain'} ? "checked" : "";
print "<br><textarea name=domain rows=3 cols=30>",
	join("\n", @{$dns->{'domain'}}),"</textarea></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\">\n"
	if ($access{'dns'} == 2);
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

