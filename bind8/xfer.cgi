#!/usr/local/bin/perl
# Force a zone transfer for a slave domain

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

# Get config object
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$file = &find_value("file", $zconf);

$desc = &ip6int_to_net(&arpa_to_ip($zone->{'name'}));
&ui_print_header($desc, $text{'xfer_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

# Get master IPs
$masters = &find("masters", $zconf);
foreach $av (@{$masters->{'members'}}) {
	push(@ips, join(" ", $av->{'name'}, @{$av->{'values'}}));
	}
print &text('xfer_doing', join(" ", @ips)),"<br>\n";
$temp = &transname();
$rv = &transfer_slave_records($zone->{'name'}, \@ips, $temp);
foreach $ip (@ips) {
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
	@recs = &read_zone_file($temp, $zone->{'name'}.".");
	print &text('xfer_count', scalar(@recs)),"<p>\n";
	}
&unlink_file($temp);

&ui_print_footer("edit_slave.cgi?index=$in{'index'}&view=$in{'view'}",
		 $text{'master_return'});
