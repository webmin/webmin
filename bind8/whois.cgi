#!/usr/local/bin/perl
# whois.cgi
# Call whois to get zone info

require './bind8-lib.pl';
&ReadParse();
$access{'whois'} || &error($text{'whois_ecannot'});

$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) || &error($text{'master_ecannot'});

$tv = $zone->{'type'};
$dom =~ s/\.$//;
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'whois_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

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
		$pserver = "-h ".$whois{$d};
		last;
		}
	}

$qdom = quotemeta($dom);
$cmd = "$config{'whois_cmd'} $server $qdom";
$pcmd = "$config{'whois_cmd'} $pserver $dom";
$out = `$cmd 2>&1`;
if ($out =~ /whois\s+server:\s+(\S+)/i) {
	$cmd = "$config{'whois_cmd'} -h ".quotemeta($1)." $qdom";
	$pcmd = "$config{'whois_cmd'} -h $1 $dom";
	$out = `$cmd 2>&1`;
	}
print &ui_table_start(&text('whois_header', "<tt>".&html_escape($pcmd)."</tt>"),
		      "width=100%", 2);
print &ui_table_row(undef, "<pre>".&html_escape($out)."</pre>", 2);
print &ui_table_end();

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?zone=$in{'zone'}&view=$in{'view'}", $text{'master_return'});

