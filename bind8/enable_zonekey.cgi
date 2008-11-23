#!/usr/local/bin/perl
# Create a signing key for a zone, add it, and sign the zone

require './bind8-lib.pl';
&error_setup($text{'zonekey_err'});
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));

# Validate inputs and compute size
($min, $max, $factor) = &dnssec_size_range($in{'alg'});
if ($in{'size_def'} == 1) {
	$size = int(($max + $min) / 2);
	if ($factor) {
		$size = int($size / $factor) * $factor;
		}
	}
elsif ($in{'size_def'} == 2) {
	# Max allowed
	$size = $max;
	}
else {
	$in{'size'} =~ /^\d+$/ && $in{'size'} >= $min && $in{'size'} <= $max ||
		&error(&text('zonekey_esize', $min, $max));
	if ($factor && $in{'size'} % $factor) {
		&error(&text('zonekey_efactor', $factor));
		}
	$size = $in{'size'};
	}

&ui_print_unbuffered_header($desc, $text{'zonekey_title'}, "",
			    undef, undef, undef, undef, &restart_links($zone));

# Create the key
&lock_file(&make_chroot(&absolute_path($zone->{'file'})));
print &text('zonekey_creating', $dom),"<br>\n";
$err = &create_dnssec_key($zone, $in{'alg'}, $size);
if ($err) {
	print &text('zonekey_ecreate', $err),"<p>\n";
	}
else {
	print $text{'zonekey_done'},"<p>\n";

	# Sign the zone
	print &text('zonekey_signing', $dom),"<br>\n";
	$err = &sign_dnssec_zone($zone);
	if ($err) {
		print &text('zonekey_esign', $err),"<p>\n";
		}
	else {
		print $text{'zonekey_done'},"<p>\n";
		}

	# Show the key
	# XXX
	}

&unlock_file(&make_chroot(&absolute_path($zone->{'file'})));
&webmin_log("zonekeyon", undef, $dom);
&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
		 $text{'master_return'});

