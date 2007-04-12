#!/usr/local/bin/perl
# edit_master.cgi
# Display options and directives in an existing master zone

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
&can_edit_zone($zone) || &error($text{'master_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_title'}, "");

# Find the record types
if (!$config{'largezones'}) {
	@recs = grep { !$_->{'generate'} && !$_->{'defttl'} }
		     &read_zone_file($zone->{'file'}, $dom);
	}
if ($dom =~ /in-addr\.arpa/i || $dom =~ /\.$ipv6revzone/i) {
	@rcodes = &get_reverse_record_types();
	}
else {
	@rcodes = &get_forward_record_types();
	}
push(@rcodes, "ALL");
@rcodes = grep { &can_edit_type($_, \%access) } @rcodes;

if (!$config{'largezones'}) {
	# See what record type we have
	foreach $c (@rcodes) { $rnum{$c} = 0; }
	foreach $r (@recs) {
		$rnum{$r->{'type'}}++;
		$rnum{"ALL"}++ if ($r->{'type'} ne "SOA");
		if ($r->{'type'} eq "SOA") { $soa = $r; }
		}
	}
else {
	# Just assume that we have all types
	$soa = 1;
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
		push(@rlinks, "edit_recs.cgi?index=$in{'index'}&".
			      "view=$in{'view'}&type=$rcodes[$i]");
		push(@rtitles, ($text{"type_$rcodes[$i]"} || $rcodes[$i]).
			       (defined(%rnum) ? " ($rnum{$rcodes[$i]})" : ""));
		push(@ricons, $is_extra{$rcodes[$i]} ?
				"images/extra.gif" : "images/$rcodes[$i].gif");
		}
	&icons_table(\@rlinks, \@rtitles, \@ricons);
	}

# links to forms editing text, soa and zone options
if ($access{'file'}) {
	push(@links, "edit_text.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_manual'});
	push(@images, "images/text.gif");
	}
if ($access{'params'}) {
	push(@links, "edit_soa.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_soa'});
	push(@images, "images/soa.gif");
	}
if ($access{'opts'}) {
	push(@links, "edit_options.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_options'});
	push(@images, "images/options.gif");
	}
if ($access{'findfree'}) {
	push(@links, "find_free.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'findfree_desc'});
	push(@images, "images/findfree.gif");
	}
if ($access{'gen'}) {
	push(@links, "list_gen.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'gen_title'});
	push(@images, "images/gen.gif");
	}
if ($access{'whois'} && &has_command($config{'whois_cmd'}) &&
    $dom !~ /in-addr\.arpa/i) {
	push(@links, "whois.cgi?index=$in{'index'}&view=$in{'view'}");
	push(@titles, $text{'master_whois'});
	push(@images, "images/whois.gif");
	}

if (@links) {
	print "<hr>\n";
	&icons_table(\@links, \@titles, \@images);
	}

$apply = $access{'apply'} && &has_ndc();
if (!$access{'ro'} && ($access{'delete'} || $apply)) {
	print "<hr>\n";
	print "<table width=100%>\n";

	if ($access{'delete'}) {
		# Show button to delete zome
		print "<form action=delete_zone.cgi>\n";
		print "<input type=hidden name=index value=\"$in{'index'}\">\n";
		print "<input type=hidden name=view value=\"$in{'view'}\">\n";
		print "<tr><td>\n";
		print "<input type=submit value=\"$text{'master_del'}\">\n";
		print "</td> <td>$text{'master_delmsg'}\n";
		if ($dom !~ /in-addr\.arpa/i && $dom !~ /\.$ipv6revzone/i) {
			print "$text{'master_delrev'}\n";
			}
		print "</td> </tr></form>\n";
		}

	if ($apply) {
		# Show button to do an NDC reload
		print "<form action=restart_zone.cgi>\n";
		print "<input type=hidden name=index value=\"$in{'index'}\">\n";
		print "<input type=hidden name=view value=\"$in{'view'}\">\n";
		print "<tr><td>\n";
		print "<input type=submit value=\"$text{'master_apply'}\">\n";
		$args = $view ? "$dom IN $view->{'value'}" : $dom;
		$cmd = &has_ndc() == 2 ? $config{'rndc_cmd'}
				       : $config{'ndc_cmd'};
		print "</td> <td>",&text('master_applymsg',
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
		defined(%rnum) ? ( $text{'master_records'} ) : ( )
		], 100);
	for($i=0; $_[$i]; $i++) {
		local @cols = ( "<a href=\"edit_recs.cgi?".
		      "index=$in{'index'}&view=$in{'view'}&type=$_[$i]\">".
		      ($text{"recs_$_[$i]"} || $_[$i])."</a>" );
		if (defined(%rnum)) {
			push(@cols, $rnum{$_[$i]});
			}
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
}

