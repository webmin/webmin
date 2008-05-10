#!/usr/local/bin/perl
# edit_slave.cgi
# Display records and other info for an existing slave or stub zone

require './bind8-lib.pl';
&ReadParse();
if ($in{'zone'}) {
	$zone = &get_zone_name($in{'zone'}, 'any');
	$in{'index'} = $zone->{'index'};
	$in{'view'} = $zone->{'viewindex'};
	}
else {
	$zone = &get_zone_name($in{'index'}, $in{'view'});
	}
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'slave_ecannot'});

$desc = &ip6int_to_net(&arpa_to_ip($dom));
if ($zone->{'file'}) {
	@st = stat(&make_chroot($zone->{'file'}));
	$lasttrans = &text('slave_last', @st && $st[7] ? &make_date($st[9])
					     	       : $text{'slave_never'});
	}
&ui_print_header($desc, $0 =~ /edit_slave/ ? $text{'slave_title'}
					   : $text{'stub_title'},
		 "", undef, 0, 0, 0, undef, undef, undef, $lasttrans);

if ($zone->{'file'}) {
	print "<p>\n";
	@recs = &read_zone_file($zone->{'file'}, $dom);
	if ($dom =~ /in-addr\.arpa/i || $dom =~ /\.$ipv6revzone/i) {
		@rcodes = &get_reverse_record_types();
		}
	else {
		@rcodes = &get_forward_record_types();
		}
	foreach $c (@rcodes) { $rnum{$c} = 0; }
	foreach $r (@recs) {
		$rnum{$r->{'type'}}++;
		if ($r->{'type'} eq "SOA") { $soa = $r; }
		}
	if ($config{'show_list'}) {
		# display as list
		$mid = int((@rcodes+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&types_table(@rcodes[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		&types_table(@rcodes[$mid..$#rcodes]);
		print "</td></tr> </table>\n";
		}
	else {
		# display as icons
		for($i=0; $i<@rcodes; $i++) {
			push(@rlinks, "edit_recs.cgi?index=$in{'index'}".
				      "&view=$in{'view'}&type=$rcodes[$i]");
			push(@rtitles, $text{"type_$rcodes[$i]"}.
				       " ($rnum{$rcodes[$i]})");
			push(@ricons, "images/$rcodes[$i].gif");
			}
		&icons_table(\@rlinks, \@rtitles, \@ricons);
		}
	$done_recs = 1;
	}

# Shut buttons for editing, options and whois
if ($access{'file'} && $zone->{'file'}) {
	push(@links, "view_text.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'slave_manual'});
	push(@images, "images/text.gif");
	}
if ($access{'opts'}) {
	push(@links, "edit_soptions.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_options'});
	push(@images, "images/options.gif");
	}
if ($access{'whois'} && &has_command($config{'whois_cmd'}) &&
    $dom !~ /in-addr\.arpa/i) {
	push(@links, "whois.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_whois'});
	push(@images, "images/whois.gif");
	}
if (@links) {
	print &ui_hr() if ($done_recs);
	&icons_table(\@links, \@titles, \@images);
	}

$apply = $access{'apply'} && &has_ndc();
if (!$access{'ro'} && ($access{'delete'} || $apply)) {
	print &ui_hr();
	print "<table width=100%>\n";

	if ($access{'delete'}) {
		print "<form action=delete_zone.cgi>\n";
		print "<input type=hidden name=index value=\"$in{'index'}\">\n";
		print "<input type=hidden name=view value=\"$in{'view'}\">\n";
		print "<tr><td>\n";
		print "<input type=submit value=\"$text{'master_del'}\">\n";
		print "</td> <td>$text{'slave_delmsg'}\n";
		print "</td> </tr></form>\n";
		}

	if ($apply) {
		# Show button to do an NDC reload
		print "<form action=restart_zone.cgi>\n";
		print "<input type=hidden name=index value=\"$in{'index'}\">\n";
		print "<input type=hidden name=view value=\"$in{'view'}\">\n";
		print "<tr><td>\n";
		print "<input type=submit value=\"$text{'slave_apply'}\">\n";
		$args = $zone->{'view'} ? "$dom IN $zone->{'view'}" : $dom;
		$cmd = &has_ndc() == 2 ? $config{'rndc_cmd'}
				       : $config{'ndc_cmd'};
		print "</td> <td>",&text('slave_applymsg',
			"<tt>$cmd reload $args</tt>");
		print "</td> </tr></form>\n";
		}

	print "</table>\n";
	}

&ui_print_footer("", $text{'index_return'});

sub types_table
{
if ($_[0]) {
	local($i);
	print &ui_columns_start([
		$text{'master_type'},
		$text{'master_records'},
		], 100);
	for($i=0; $_[$i]; $i++) {
		local @cols = ( "<a href=\"edit_recs.cgi?".
		      "index=$in{'index'}&view=$in{'view'}&type=$_[$i]\">".
		      ($text{"recs_$_[$i]"} || $_[$i])."</a>",
		      $rnum{$_[$i]} );
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
}

