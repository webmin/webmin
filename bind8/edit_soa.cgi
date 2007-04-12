#!/usr/local/bin/perl
# edit_soa.cgi
# Display the SOA for an existing master zone

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'params'} || &error($text{'master_esoacannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_params'}, "");

@recs = &read_zone_file($zone->{'file'}, $dom);
foreach $r (@recs) {
	$soa = $r if ($r->{'type'} eq "SOA");
	$defttl = $r if ($r->{'defttl'});
	}
$v = $soa->{'values'};

# form for editing SOA record
print "<form action=save_soa.cgi>\n";
print "<input type=hidden name=file value=\"$soa->{'file'}\">\n";
print "<input type=hidden name=num value=\"$soa->{'num'}\">\n";
print "<input type=hidden name=origin value=\"$dom\">\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<input type=hidden name=view value=\"$in{'view'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'master_params'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'master_server'}</b></td>\n";
print "<td><input name=master size=20 value=\"$v->[0]\"></td>\n";
$v->[1] = &dotted_to_email($v->[1]);
print "<td><b>$text{'master_email'}</b></td>\n";
print "<td><input name=email size=20 value=\"$v->[1]\"></td> </tr>\n";

@u = &extract_time_units($v->[3], $v->[4], $v->[5], $v->[6]);
print "<tr> <td><b>$text{'master_refresh'}</b></td>\n";
print "<td><input name=refresh size=10 value=\"$v->[3]\">\n";
print &time_unit_choice("refunit", $u[0]);
print "</td>\n";
print "<td><b>$text{'master_retry'}</b></td>\n";
print "<td><input name=retry size=10 value=\"$v->[4]\">\n";
print &time_unit_choice("retunit", $u[1]);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'master_expiry'}</b></td>\n";
print "<td><input name=expiry size=10 value=\"$v->[5]\">\n";
print &time_unit_choice("expunit", $u[2]);
print "</td>\n";
print "<td><b>$text{'master_minimum'}</b></td>\n";
print "<td><input name=minimum size=10 value=\"$v->[6]\">\n";
print &time_unit_choice("minunit", $u[3]);
print "</td> </tr>\n";

print "<tr>\n";
print "<td><b>$text{'master_defttl'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=defttl_def value=1 %s> %s\n",
	$defttl ? "" : "checked", $text{'default'};
printf "<input type=radio name=defttl_def value=0 %s>\n",
	$defttl ? "checked" : "";
$ttl = $defttl->{'defttl'} if ($defttl);
($ttlu) = &extract_time_units($ttl);
print "<input name=defttl size=10 value=\"$ttl\">\n";
print &time_unit_choice("defttlunit", $ttlu);
print "</td>\n";

if (!$config{'updserial_on'}) {
	print "<tr> <td><b>$text{'master_serial'}</b></td>\n";
	print "<td><input name=serial size=20 value=\"$v->[2]\"></td> </tr>\n";
	}

print "</table></td></tr> </table>\n";
print "<input type=submit value=\"$text{'save'}\">\n" if (!$access{'ro'});
print "</form><p>\n";

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'master_return'});

