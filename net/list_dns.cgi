#!/usr/local/bin/perl
# list_dns.cgi
# Display the DNS client configuration

require './net-lib.pl';
$access{'dns'} || &error($text{'dns_ecannot'});
&ui_print_header(undef, $text{'dns_title'}, "");
$dns = &get_dns_config();

# Start of the form
print &ui_form_start("save_dns.cgi");
print &ui_table_start($text{'dns_options'}, "width=100%", 4);

# Find hostname in /etc/hosts, offer to fix
@hosts = &list_hosts();
foreach $h (@hosts) {
	foreach $n (@{$h->{'hosts'}}) {
		$found++ if ($n eq &get_hostname());
		}
	}

# System's hostname
print &ui_table_row($text{'dns_hostname'},
	&ui_textbox("hostname", &get_hostname(), 40).
	($found ? "<br>".&ui_checkbox("hosts", 1, $text{'dns_hoststoo'}, 1)
		: ""), 3);

# DNS resolution order
$order = &order_input($dns);
if ($order) {
	print &ui_table_row($text{'dns_order'}, $order, 3);
	}

# Check if hostname is set from DHCP
# XXX not done yet
#$dhost = defined(&get_dhcp_hostname) ? &get_dhcp_hostname() : -1;
#if ($dhost != -1) {
#	print "<tr> <td></td>\n";
#	print "<td>",&ui_checkbox("dhcp", 1, $text{'dns_dhcp'}, $dhost),
#	      "</td> </tr>\n";
#	}

# DNS servers
@nslist = ( );
for($i=0; $i<$max_dns_servers || $i<@{$dns->{'nameserver'}}+1; $i++) {
	push(@nslist, &ui_textbox("nameserver_$i",
				  $dns->{'nameserver'}->[$i], 15));
	}
print &ui_table_row($text{'dns_servers'}.
		    ($dns->{'name'} ? " ".$dns->{'name'}[0] : ""),
	join("<br>", @nslist));
print &ui_hidden("name0", $dns->{'name'}[0]) if ($dns->{'name'});

# Additional DNS servers, as seen on Windows
if (@{$dns->{'name'}} > 1) {
    for ($j=1; $j<@{$dns->{'name'}}; $j++) {
	@nslist = ( );
	for ($i=0; $i<$max_dns_servers; $i++) {
		push(@nslist, &ui_textbox("nameserver${j}_$i",
					  $dns->{"nameserver$j"}->[$i], 15));
		}
	print &ui_table_row($text{'dns_servers'}." ".$dns->{'name'}[$j],
		join("<br>", @nslist));
	print &ui_hidden("name$j", $dns->{'name'}[$j]);
        }
    }

# DNS search domains
print &ui_table_row($text{'dns_search'},
	&ui_radio("domain_def", $dns->{'domain'} ? 0 : 1,
		  [ [ 1, $text{'dns_none'} ],
		    [ 0, $text{'dns_listed'} ] ])."<br>".
	&ui_textarea("domain", join("\n", @{$dns->{'domain'}}), 3, 30));

# End of the form
print &ui_table_end();
if ($access{'dns'} == 2) {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
else {
	print &ui_form_end();
	}

&ui_print_footer("", $text{'index_return'});

