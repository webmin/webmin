#!/usr/local/bin/perl
# Remove the signing key records for a zone
use strict;
use warnings;
our (%access, %text, %in); 

require './bind8-lib.pl';

&error_setup($text{'dt_zone_err'});
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'dnssec'} || &error($text{'dnssec_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($dom));

&ui_print_unbuffered_header($desc, $text{'dt_enable_title'}, "",
						   undef, undef, undef, undef, &restart_links($zone));

if (&have_dnssec_tools_support()) {
	print &text('dt_zone_deleting_state', $dom),"<br>\n";
	&dt_delete_dnssec_state($zone);
	print $text{'dt_zone_done'},"<br><br>\n";

	&webmin_log("zonekeyoff", undef, $dom);
}

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
				 $text{'master_return'});

