#!/usr/local/bin/perl
# Display the signing key for a zone, or offer to set one up
use strict;
use warnings;
our (%access, %in, %text, $in);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'dnssec'} || &error($text{'dnssec_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($dom));

&ui_print_header($desc, $text{'zonekey_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

# Check if the zone already has a key, from a DNSKEY record
my @keyrecs = &get_dnskey_record($zone);
if (@keyrecs) {
	# Tell the user we already have it
	print &text('zonekey_already'),"\n";
	print $text{'zonekey_webmin'},"\n";
	print "<p>\n";

	my @keys = &get_dnssec_key($zone);
	if (!@keys) {
		print &text('zonekey_noprivate'),"<p>\n";
		}
	elsif (!ref($keys[0])) {
		print &text('zonekey_eprivate', $keys[0]),"<p>\n";
		@keys = ( );
		}
	foreach my $key (@keys) {
		# Collapsible section for key details
		my $kt = $key->{'ksk'} ? 'ksk' : 'zone';
		my ($keyrec) = grep { $_->{'values'}->[0] ==
				 ($key->{'ksk'} ? 257 : 256) } @keyrecs;
		my $keyline = join(" ", $keyrec->{'name'}, $keyrec->{'class'},
				     $keyrec->{'type'}, @{$keyrec->{'values'}});
		print &ui_hidden_start($text{'zonekey_expand'.$kt},
				       $kt, 0, "edit_zonekey.cgi?$in");
		print $text{'zonekey_public'},"<br>\n";
		print &ui_textarea("keyline", $keyline, 2, 80, "off", 0,
				   "readonly style='width:90%'"),"<br>\n";
		print &text('zonekey_publicfile',
			    "<tt>$key->{'publicfile'}</tt>"),"<p>\n";

		print $text{'zonekey_private'},"<br>\n";
		print &ui_textarea(
			"private", $key->{'privatetext'}, 8, 80,
			"off", 0, "readonly style='width:90%'"),"<br>\n";
		print &text('zonekey_privatefile',
			    "<tt>$key->{'privatefile'}</tt>"),"<br>\n";
		print &ui_hidden_end();
		}

	my $ds = &get_ds_record($zone);
	if ($ds) {
		print $text{'zonekey_ds'},"<br>\n";
		print &ui_textarea("ds", $ds."\n", 2, 80, "off", 0,
				   "readonly style='width:90%'"),"<br>\n";
		}

	# Offer to disable
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("disable_zonekey.cgi", $text{'zonekey_disable'},
			      $text{'zonekey_disabledesc'},
			      &ui_hidden("view", $in{'view'}).
			      &ui_hidden("zone", $in{'zone'}));

	# Offer to sign now
	print &ui_buttons_row("sign_zone.cgi", $text{'zonekey_sign'},
			      $text{'zonekey_signdesc'},
			      &ui_hidden("view", $in{'view'}).
			      &ui_hidden("zone", $in{'zone'}));

	# Offer to re-generate now, for zones with a KSK
	if (@keys == 2) {
		print &ui_buttons_row("resign_zone.cgi",
				      $text{'zonekey_resign'},
				      $text{'zonekey_resigndesc'},
				      &ui_hidden("view", $in{'view'}).
				      &ui_hidden("zone", $in{'zone'}));
		}

	print &ui_buttons_end();
	}
else {
	# Offer to setup
	print $text{'zonekey_desc'},"<p>\n";

	print &ui_form_start("enable_zonekey.cgi", "post");
	print &ui_hidden("zone", $in{'zone'});
	print &ui_hidden("view", $in{'view'});
	print &ui_table_start($text{'zonekey_header'}, undef, 2);

	# Key algorithm
	print &ui_table_row($text{'zonekey_alg'},
		&ui_select("alg", "RSASHA1",
			   [ &list_dnssec_algorithms() ]));

	# Key size
	print &ui_table_row($text{'zonekey_size'},
		&ui_radio("size_def", 1, [ [ 1, $text{'zonekey_ave'}."<br>" ],
					   [ 2, $text{'zonekey_strong'}."<br>"],
					   [ 0, $text{'zonekey_other'} ] ]).
		" ".&ui_textbox("size", undef, 6));

	# Number of keys
	print &ui_table_row($text{'zonedef_single'},
		&ui_radio("single", 0, [ [ 0, $text{'zonedef_two'} ],
					 [ 1, $text{'zonedef_one'} ] ]));
	
	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'zonekey_enable'} ] ]);
	}

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'master_return'});
