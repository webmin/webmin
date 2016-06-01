#!/usr/local/bin/perl
# Show a list of free IP addresses, within the configured ranges
use strict;
use warnings;
our (%config, %text);

require './bind8-lib.pl';

# Go through all zones to find IPs in use, and networks
my $conf = &get_config();
my @views = &find("view", $conf);
my @zones;
my %view;
foreach my $v (@views) {
	my @vz = &find("zone", $v->{'members'});
	map { $view{$_} = $v } @vz;
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
my %taken;
my %nets;
foreach my $z (@zones) {
	my $type = &find_value("type", $z->{'members'});
	next if ($type ne "master");
	my $file = &find_value("file", $z->{'members'});
	my @recs = &read_zone_file($file, $z->{'value'});
	foreach my $r (@recs) {
		if ($r->{'type'} eq 'A') {
			$taken{$r->{'values'}->[0]}++;
			my $net = $r->{'values'}->[0];
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
my @nets;
if ($config{'free_nets'}) {
	@nets = split(/\s+/, $config{'free_nets'});
	}
else {
	@nets = keys %nets;
	}
@nets = sort { $a cmp $b } @nets;

# display list of free IPs in the nets
&popup_header($text{'free_title'});
print "<script>\n";
print "function select(f)\n";
print "{\n";
print "top.opener.ifield.value = f;\n";
print "top.close();\n";
print "return false;\n";
print "}\n";
print "</script>\n";
print &ui_columns_start([ $text{'free_ip'} ], 100);
foreach my $net (@nets) {
	my @netip = split(/\./, $net);
	my $start;
	my $end;
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
	for(my $d=$start; $d<=$end; $d++) {
		my $ip = "$netip[0].$netip[1].$netip[2].$d";
		if (!$taken{$ip}) {
			print &ui_columns_row([ &ui_link("", $ip, undef, "onClick='return select(\"$ip\");'") ]);
			}
		}
	}
print &ui_columns_end();
&popup_footer();

