#!/usr/local/bin/perl
# whois.cgi
# Call whois to get zone info

require './bind8-lib.pl';
&ReadParse();
$access{'whois'} || &error($text{'whois_ecannot'});
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
$tv = $zone->{'type'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'whois_title'}, "");

# Find the best whois server for the domain
foreach $wf ("$module_root_directory/whois-servers",
	     "$module_config_directory/whois-servers") {
	open(WHOIS, $wf);
	while(<WHOIS>) {
		s/\r|\n//g;
		local ($wdom, $wserv) = split(/\s+/);
		$whois{$wdom} = $wserv;
		}
	close(WHOIS);
	}
foreach $d (sort { length($b) <=> length($a) } keys %whois) {
	if ($dom =~ /\Q$d\E$/) {
		$server = "-h ".quotemeta($whois{$d});
		last;
		}
	}

$qdom = quotemeta($dom);
$cmd = "$config{'whois_cmd'} $server $qdom";
$out = `$cmd 2>&1`;
if ($out =~ /whois\s+server:\s+(\S+)/i) {
	$cmd = "$config{'whois_cmd'} -h $1 '$dom'";
	$out = `$cmd 2>&1`;
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('whois_header', "<tt>$cmd</tt>"),
      "</b></td> </tr>\n";
print "<tr $cb> <td><pre>",&html_escape($out);
print "</pre></td> </tr></table><br>\n";

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?index=$in{'index'}&view=$in{'view'}", $text{'master_return'});

