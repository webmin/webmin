#!/usr/local/bin/perl
# Create a signing key for a zone, add it, and sign the zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&error_setup($text{'zonekey_err'});
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($dom));

# Validate inputs and compute size
my ($ok, $size) = &compute_dnssec_key_size($in{'alg'}, $in{'size_def'},
					   $in{'size'});
&error($size) if (!$ok);

&ui_print_unbuffered_header($desc, $text{'zonekey_title'}, "",
			    undef, undef, undef, undef, &restart_links($zone));

# Create the key
&lock_file(&make_chroot(&absolute_path($zone->{'file'})));
print &text('zonekey_creating', $dom),"<br>\n";
my $err = &create_dnssec_key($zone, $in{'alg'}, $size, $in{'single'});
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
	}

&unlock_file(&make_chroot(&absolute_path($zone->{'file'})));
&webmin_log("zonekeyon", undef, $dom);
&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
		 $text{'master_return'});

