#!/usr/local/bin/perl
# Show a list of free IPs in all subnets

$trust_unknown_referers = 1;
require './dhcp-dns-lib.pl';
&popup_header($text{'chooser_title'});
&foreign_require("net", "net-lib.pl");

# Build map of all IPs
@subnets = &list_dhcp_subnets();
@hosts = &list_dhcp_hosts();
foreach $s (@subnets) {
	$sip = $s->{'values'}->[0];
	$smask = $s->{'values'}->[2];
	$sipnum = &net::ip_to_integer($sip);
	$smasknum = &net::ip_to_integer($smask);
	$basenum = $sipnum & $smasknum;
	$topnum = $basenum + ~$smasknum - 1;
	for($i=$basenum; $i<=$topnum; $i++) {
		$poss{&net::integer_to_ip($i)} = $s;
		}
	}

# Find those that are free
foreach $h (@hosts) {
	$fixed = &dhcpd::find("fixed-address", $h->{'members'});
	if ($fixed) {
		$used{&to_ipaddress($fixed->{'values'}->[0])} = 1;
		}
	}
foreach $ip (keys %poss) {
	if (!$used{$ip}) {
		push(@avail, $ip);
		}
	}
@avail = sort { @a = split(/\./, $a);
		@b = split(/\./, $b);
		$a[0] <=> $b[0] || $a[1] <=> $b[1] ||
	         $a[2] <=> $b[2] || $a[3] <=> $b[3] } @avail;

print <<EOF;
<script>
function select(ip)
{
top.opener.ifield.value = ip;
top.close();
return false;
}
</script>
EOF
if (@avail) {
	print &ui_columns_start([ $text{'chooser_ip'} ], 100);
	foreach $ip (@avail) {
		print &ui_columns_row([
			"<a href='' onClick='return select(\"$ip\")'>$ip</a>"
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'chooser_none'}</b><p>\n";
	}

&popup_footer();

