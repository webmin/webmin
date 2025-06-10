#!/usr/local/bin/perl
# Migrate an existing DNSSEC signed zone to using the DNSSEC-Tools suite for DNSSEC-related automation 
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

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
	my $zonefile = &get_zone_file($zone);
	my $krfile = "$zonefile".".krf";
	my $z_chroot = &make_chroot($zonefile);
	my $k_chroot = &make_chroot($krfile);
	my $rrfile;

	&lock_file($z_chroot);

	# generate the keyrec file
	print &text('dt_zone_createkrf', $dom),"<br>\n";
	my $err = &dt_genkrf($zone, $z_chroot, $k_chroot); 
	if ($err) {
		&unlock_file($z_chroot);
		&error($err);
	}

	print $text{'dt_zone_done'},"<br><br>\n";

	# resign the zone
	print &text('dt_zone_signing', $dom),"<br>\n";
	$err = &dt_resign_zone($dom, $zonefile, $krfile, 0);
	if ($err) {
		&unlock_file($z_chroot);
		&error($err);
	}
	print $text{'dt_zone_done'},"<br><br>\n";

	# Create rollrec entry for zone
	print &text('dt_zone_rrf_updating', $dom),"<br>\n";
	$rrfile = $config{"dnssectools_rollrec"};
	&lock_file($rrfile);
	open(my $OUT, ">>", $rrfile) || &error($text{'dt_zone_errfopen'});
	print $OUT "roll \"$dom\"\n";
	print $OUT " zonename    \"$dom\"\n";
	print $OUT " zonefile    \"$z_chroot\"\n";
	print $OUT " keyrec      \"$k_chroot\"\n";
	print $OUT " kskphase    \"0\"\n";
	print $OUT " zskphase    \"0\"\n";
	print $OUT " ksk_rolldate    \" \"\n";
	print $OUT " ksk_rollsecs    \"0\"\n";
	print $OUT " zsk_rolldate    \" \"\n";
	print $OUT " zsk_rollsecs    \"0\"\n";
	print $OUT " maxttl      \"0\"\n";
	print $OUT " phasestart  \"new\"\n";
	close($OUT);
	&unlock_file($config{"dnssectools_rollrec"});
	print $text{'dt_zone_done'},"<br>\n";

	&unlock_file($z_chroot);

   &dt_rollerd_restart();
  	&restart_bind();
	&webmin_log("migrate", undef, $dom);
}

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
				 $text{'master_return'});
