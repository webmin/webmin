#!/usr/local/bin/perl
# Display the signing key for a zone, or offer to set one up
use strict;
use warnings;
our (%access, %text, %in, %config, $in);

require './bind8-lib.pl';

&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'dnssec'} || &error($text{'dnssec_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($dom));

&ui_print_header($desc, $text{'dt_zone_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

my $rrr;
# Check if zone is currently being managed by dnssec-tools
if (&have_dnssec_tools_support()) {
	my $rrfile = $config{"dnssectools_rollrec"};
	&lock_file($rrfile);
	rollrec_read($rrfile);
	$rrr = rollrec_fullrec($dom);
	if ($rrr) {
		# yes, it is managed by d-t
	
		print "<br>\n<br>\n";
	
		# Show existing keyset and DS
		print &ui_hidden_start($text{'dt_zone_expandsep'},
							   "sep", 0, "edit_zonedt.cgi?$in");
		my @keys = &get_dnskey_rrset($zone);
		foreach my $key (@keys) {
			# Check if this is a KSK
			my $ksk = $key->{'values'}->[0] % 2 ? 1 : 0;
	
			# Collapsible section for KSK details
			if ($ksk) {
				# parse the key record into a record
				my $keyline = join(" ", $key->{'name'}, $key->{'ttl'}, 
								$key->{'class'}, $key->{'type'}, @{$key->{'values'}});
				my $dsline = "";
				my @dsalgs = &list_dnssec_dshash(); 
				foreach my $alg (@dsalgs) {
					my $keyrr = Net::DNS::RR->new($keyline);
					if ($keyrr) {
						my $dsrr = create Net::DNS::RR::DS($keyrr, digtype => "$alg");
						if ($dsrr) {
							$dsline = $dsline . $dsrr->string . "<br>\n";
						}
					}
				}
	
				print $text{'dt_zone_ksksep'},"<br>\n";
				print &ui_textarea("keyline", $keyline, 2, 80, "off", 0,
								   "readonly style='width:90%'"),"<p>\n";
				print $text{'dt_zone_dssep'},"<br>\n";
				print &ui_textarea("dsline", $dsline, 2, 80, "off", 0,
								   "readonly style='width:90%'"),"<p>\n";
			}
		}
		print &ui_hidden_end();
		print "<br>\n<br>\n";
		print &ui_hr();
		print "<br>\n<br>\n";
	
		# Offer choices to manage DNSSEC operations
	
		# Check if rollerd is running
		my $rmgr_pid = $config{"dnssectools_rollmgr_pidfile"};
		if ($rmgr_pid && !(&check_pid_file($rmgr_pid))) {
			# Offer to start rollerd
			print &ui_buttons_start();
			print &ui_buttons_row("zone_dnssecmgt_dt.cgi",
								  $text{'dt_zone_rollerdrst'},
								  $text{'dt_zone_rollerdrstdesc'},
								  &ui_hidden("view", $in{'view'}).
								  &ui_hidden("zone", $in{'zone'}).
								  &ui_hidden("optype", "rollerdrst"));
			print &ui_buttons_end();
			print "<br>\n<br>\n";
			print &ui_hr();
			print "<br>\n<br>\n";
		} else {
	
			if(($rrr->{'zskphase'} == 0) && ($rrr->{'kskphase'} == 0))  {
				print &ui_buttons_start();
				print &ui_buttons_row("zone_dnssecmgt_dt.cgi",
									  $text{'dt_zone_zskroll'},
									  $text{'dt_zone_zskrolldesc'},
									  &ui_hidden("view", $in{'view'}).
									  &ui_hidden("zone", $in{'zone'}).
									  &ui_hidden("optype", "zskroll"));
				print &ui_buttons_row("zone_dnssecmgt_dt.cgi",
									  $text{'dt_zone_kskroll'},
									  $text{'dt_zone_kskrolldesc'},
									  &ui_hidden("view", $in{'view'}).
									  &ui_hidden("zone", $in{'zone'}).
									  &ui_hidden("optype", "kskroll"));
				print &ui_buttons_end();
				print "<br>\n<br>\n";
				print &ui_hr();
				print "<br>\n<br>\n";
	
			} elsif($rrr->{'kskphase'} == 6) { 
				# if KSK rollphase has reached 6, we need to notify parent
				print &ui_buttons_start();
				print &ui_buttons_row("zone_dnssecmgt_dt.cgi",
									  $text{'dt_zone_ksknotify'},
									  $text{'dt_zone_ksknotifydesc'},
									  &ui_hidden("view", $in{'view'}).
									  &ui_hidden("zone", $in{'zone'}).
									  &ui_hidden("optype", "notify"));
				print &ui_buttons_end();
				print "<br>\n<br>\n";
				print &ui_hr();
				print "<br>\n<br>\n";
	
			} else {
				my $lsdnssec;
				# Display rollerd status for this zone
				print $text{'dt_zone_keyrollon'},"<br>\n";
				print "<br>\n<br>\n";
	
				if ((($lsdnssec=dt_cmdpath('lsdnssec')) ne '')) {
					my $cmd = "$lsdnssec -z $dom $rrfile";
					my $out = &backquote_command("$cmd");
					print &ui_textarea("lsdnssec", $out, 12, 80, "soft", 0,
								   "readonly style='width:90%'");
					print "<br>\n<br>\n";
				}
	
				print &ui_hr();
				print "<br>\n<br>\n";
			}
		}
	
		# Offer to re-sign this zone 
		print &ui_buttons_start();
		print &ui_buttons_row("zone_dnssecmgt_dt.cgi",
							  $text{'dt_zone_resign'},
							  $text{'dt_zone_resigndesc'},
							  &ui_hidden("view", $in{'view'}).
							  &ui_hidden("zone", $in{'zone'}).
							  &ui_hidden("optype", "resign"));
		print &ui_buttons_end();
		print "<br>\n<br>\n";
		print &ui_hr();
		print "<br>\n<br>\n";
	
		# Offer to disable dnssec-tools for this zone 
		print &ui_buttons_start();
		print &ui_buttons_row("disable_zonedt.cgi", $text{'dt_zone_disable'},
							  $text{'dt_zone_disabledesc'},
							  &ui_hidden("view", $in{'view'}).
							  &ui_hidden("zone", $in{'zone'}));
		print &ui_buttons_end();
		print "<br>\n<br>\n";
		print "<br>\n<br>\n";
	
	} else {
	
		# no, it's not managed by d-t
		
		# Check if the zone already has a key, from a DNSKEY record
		my $keyrec = &get_dnskey_record($zone);
		if ($keyrec) {
			# Tell the user we already have it
			print &text('dt_zone_already'),"\n";
	
			print &ui_hr();
			print &ui_buttons_start();
	
			# Offer to migrate existing keys to dnssec-tools 
			print &ui_buttons_row("zone_dnssecmigrate_dt.cgi", $text{'dt_zone_migrate'},
								  $text{'dt_zone_migratedesc'},
								  &ui_hidden("view", $in{'view'}).
								  &ui_hidden("zone", $in{'zone'}));
	
			# Offer to remove existing keys
			print &ui_buttons_row("disable_zonekey.cgi", $text{'zonekey_disable'},
								  $text{'zonekey_disabledesc'},
								  &ui_hidden("view", $in{'view'}).
								  &ui_hidden("zone", $in{'zone'}));
	
			print &ui_buttons_end();
	
		} else {
	
			# Offer to enable dnssec-tools for this zone 
	
			print $text{'dt_zone_desc'},"<p>\n";
	
			print &ui_form_start("enable_zonedt.cgi", "post");
			print &ui_hidden("zone", $in{'zone'});
			print &ui_hidden("view", $in{'view'});
	
			print &ui_table_start($text{'dt_zone_header'}, undef, 2);
			# Key algorithm
			print &ui_table_row($text{'dt_zone_dne'},
			&ui_select("dne", "NSEC",
				   [ &list_dnssec_dne() ]));
			print &ui_table_end();
	
			print &ui_form_end([ [ undef, $text{'dt_zone_enable'} ] ]);
	
		}
	}
	rollrec_close();
	&unlock_file($rrfile);
}

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'master_return'});
