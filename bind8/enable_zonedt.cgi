
#!/usr/local/bin/perl
# Create a signing key for a zone, add it, and sign the zone

require './bind8-lib.pl';

local $zone;
local $dom;
local $desc;

&error_setup($text{'dt_zone_err'});
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));

&ui_print_unbuffered_header($desc, $text{'dt_enable_title'}, "",
							undef, undef, undef, undef, &restart_links($zone));

if (&have_dnssec_tools_support()) {
	my $err;
	my $nsec3 = 0;

	if ($in{'dne'} eq "NSEC") {
		$nsec3 = 0;
	} elsif ($in{'dne'} eq "NSEC3") {
		$nsec3 = 1;
	} else {
		&error($text{'dt_zone_edne'}); 
	}

	# Sign zone 
	print &text('dt_zone_signing', $dom),"<br>\n";
	$err = &dt_sign_zone($zone, $nsec3);
	&error($err) if ($err);
	print $text{'dt_zone_done'},"<br>\n";

	&webmin_log("zonekeyon", undef, $dom);
}

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
		 $text{'master_return'});

