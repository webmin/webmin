#!/usr/local/bin/perl
# Show a list of free IP addresses, within the configured ranges

require './bind8-lib.pl';

# Go through all zones to find IPs in use, and networks
$conf = &get_config();
@views = &find("view", $conf);
foreach $v (@views) {
	@vz = &find("zone", $v->{'members'});
	map { $view{$_} = $v } @vz;
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
foreach $z (@zones) {
	$type = &find_value("type", $z->{'members'});
	next if ($type ne "master");
	$file = &find_value("file", $z->{'members'});
	@recs = &read_zone_file($file, $z->{'value'});
	foreach $r (@recs) {
		if ($r->{'type'} eq 'A') {
			$taken{$r->{'values'}->[0]}++;
			$net = $r->{'values'}->[0];
			$net =~ s/\d+$/0/;
			if ($net ne "127.0.0.0") {
				$nets{$net}++;
				}
			}
		elsif ($r->{'type'} eq 'PTR') {
			$taken{&arpa_to_ip($r->{'values'}->[0])}++;
			}
		}
	}

# Use configured networks, if any
if ($config{'free_nets'}) {
	@nets = split(/\s+/, $config{'free_nets'});
	}
else {
	@nets = keys %nets;
	}
@nets = sort { $a cmp $b } @nets;

# display list of free IPs in the nets
&header();
print "<script>\n";
print "function select(f)\n";
print "{\n";
print "top.opener.ifield.value = f;\n";
print "top.close();\n";
print "return false;\n";
print "}\n";
print "</script>\n";
print "<title>$text{'free_title'}</title>\n";
print "<table width=100%>\n";
foreach $net (@nets) {
	@netip = split(/\./, $net);
	if ($netip[3] eq "0") {
		$start = 1;
		$end = 255;
		}
	elsif ($netip[3] =~ /^(\d+)\-(\d+)$/) {
		$start = $1;
		$end = $2;
		}
	else {
		$start = $end = $netip[3];
		}
	for($d=$start; $d<=$end; $d++) {
		$ip = "$netip[0].$netip[1].$netip[2].$d";
		if (!$taken{$ip}) {
			print "<tr> <td><a href=\"\" onClick='return select(\"$ip\")'>$ip</a></td> </tr>\n";
			}
		}
	}
print "</table>\n";
&ui_print_footer();

