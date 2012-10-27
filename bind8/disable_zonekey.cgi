#!/usr/local/bin/perl
# Remove the signing key records for a zone

require './bind8-lib.pl';
&error_setup($text{'zonekey_err'});
&ReadParse();
$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));

&lock_file(&make_chroot(&absolute_path($zone->{'file'})));
$key = &get_dnssec_key($zone);
if ($key) {
	@keyfiles = map { $k->{$_} } ('publicfile', 'privatefile');
	}
foreach my $k (@keyfiles) {
	&lock_file($k);
	}
&delete_dnssec_key($zone);
foreach my $k (@keyfiles) {
	&unlock_file($k);
	}
&unlock_file(&make_chroot(&absolute_path($zone->{'file'})));

&webmin_log("zonekeyoff", undef, $dom);
&redirect("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}");

