#!/usr/local/bin/perl
# Force a zone transfer for a slave domain

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $z = &zone_to_config($zone);
my $zconf = $z->{'members'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

my $desc = &ip6int_to_net(&arpa_to_ip($zone->{'name'}));
&ui_print_header($desc, $text{'xfer_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

# Get transfer source IP
my $options = &find("options", $zconf);
my $src = &find("transfer-source", $options->{'members'});

# Get master IPs
my $masters = &find("masters", $zconf);
my @ips;
foreach my $av (@{$masters->{'members'}}) {
	push(@ips, join(" ", $av->{'name'}, @{$av->{'values'}}));
	}
print &text('xfer_doing', join(" ", @ips)),"<br>\n";
my $temp = &transname();
my $rv = &transfer_slave_records($zone->{'name'}, \@ips, $temp,
			      $src ? $src->{'values'}->[0] : undef,
			      $src && @{$src->{'values'}} > 2 ?
				$src->{'values'}->[2] : undef);
foreach my $ip (@ips) {
	if ($rv->{$ip}) {
		print &text('xfer_failed', $ip,
		    "<font color=red>".&html_escape($rv->{$ip})."</font>"),
		    "<br>\n";
		}
	else {
		print &text('xfer_done', $ip),"<br>\n";
		}
	}
print "<p>\n";

# Show records
if (-r $temp) {
	my @recs = &read_zone_file($temp, $zone->{'name'}.".", undef, 0, 1);
	if (@recs) {
		print &text('xfer_count', scalar(@recs)),"<p>\n";
		}
	else {
		print "<font color=red>$text{'xfer_none'}</font><p>\n";
		}
	}
&unlink_file($temp);

&ui_print_footer("edit_slave.cgi?zone=$in{'zone'}&view=$in{'view'}",
		 $text{'master_return'});
