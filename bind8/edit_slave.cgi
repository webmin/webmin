#!/usr/local/bin/perl
# edit_slave.cgi
# Display records and other info for an existing slave or stub zone
use strict;
use warnings;
our (%access, %text, %in, %config); 

require './bind8-lib.pl';
&ReadParse();
our $ipv6revzone;

$in{'view'} = 'any' if ($in{'view'} eq '');
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) || &error($text{'master_ecannot'});

my $desc = &ip6int_to_net(&arpa_to_ip($dom));
my @st;
my $lasttrans;
if ($zone->{'file'}) {
	@st = stat(&make_chroot(&absolute_path($zone->{'file'})));
	$lasttrans = &text('slave_last', @st && $st[7] ? &make_date($st[9])
					     	       : $text{'slave_never'});
	}
&ui_print_header($desc, $0 =~ /edit_slave/ ? $text{'slave_title'}
					   : $text{'stub_title'},
		 "", undef, 0, 0, 0, &restart_links($zone),
		 undef, undef, $lasttrans);

my (@rcodes, @rtitles, @rlinks, @ricons, %rnum, $done_recs); 
if ($zone->{'file'} && -r $zone->{'file'}) {
	print "<p>\n";
	my @recs = &read_zone_file($zone->{'file'}, $dom);
	if ($dom =~ /in-addr\.arpa/i || $dom =~ /\.$ipv6revzone/i) {
		@rcodes = &get_reverse_record_types();
		}
	else {
		@rcodes = &get_forward_record_types();
		}
	foreach my $c (@rcodes) { $rnum{$c} = 0; }
	foreach my $r (@recs) {
		$rnum{$r->{'type'}}++;
		}
	if ($config{'show_list'}) {
		# display as list
		my $mid = int((@rcodes+1)/2);
		my @grid = ( );
		push(@grid, &types_table(@rcodes[0..$mid-1]));
		push(@grid, &types_table(@rcodes[$mid..$#rcodes]));
		print &ui_grid_table(\@grid, 2, 100,
			[ "width=50%", "width=50%" ]);
		}
	else {
		# display as icons
		for(my $i=0; $i<@rcodes; $i++) {
			push(@rlinks, "edit_recs.cgi?zone=$in{'zone'}".
				      "&view=$in{'view'}&type=$rcodes[$i]");
			push(@rtitles, $text{"type_$rcodes[$i]"}.
				       " ($rnum{$rcodes[$i]})");
			push(@ricons, "images/$rcodes[$i].gif");
			}
		&icons_table(\@rlinks, \@rtitles, \@ricons);
		}
	$done_recs = 1;
	}

my (@links, @titles, @images);
# Shut buttons for editing, options and whois
if ($access{'file'} && $zone->{'file'}) {
	push(@links, "view_text.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'slave_manual'});
	push(@images, "images/text.gif");
	}
if ($access{'opts'}) {
	push(@links, "edit_soptions.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_options'});
	push(@images, "images/options.gif");
	}
if ($access{'whois'} && &has_command($config{'whois_cmd'}) &&
    $dom !~ /in-addr\.arpa/i) {
	push(@links, "whois.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_whois'});
	push(@images, "images/whois.gif");
	}
push(@links, "xfer.cgi?zone=$in{'zone'}&view=$in{'view'}");
push(@titles, $text{'slave_xfer'});
push(@images, "images/xfer.gif");
if (@links) {
	print &ui_hr() if ($done_recs);
	&icons_table(\@links, \@titles, \@images);
	}

my $apply = $access{'apply'} && &has_ndc();
if (!$access{'ro'} && ($access{'delete'} || $apply)) {
	print &ui_hr();
	print &ui_buttons_start();

	# Move to other view
	my $conf = &get_config();
	print &move_zone_button($conf, $zone->{'viewindex'}, $in{'zone'});

	# Convert to master zone
	if ($access{'master'} && $st[7]) {
		print &ui_buttons_row("convert_slave.cgi",
			$text{'slave_convert'},
			$text{'slave_convertdesc'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'}));
		}

	# Delete zone
	if ($access{'delete'}) {
		print &ui_buttons_row("delete_zone.cgi",
			$text{'master_del'}, $text{'slave_delmsg'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'index_return'});

sub types_table
{
my $rv;
if ($_[0]) {
	$rv .= &ui_columns_start([
		$text{'master_type'},
		$text{'master_records'},
		], 100);
	for(my $i=0; $_[$i]; $i++) {
		my @cols = ( &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$_[$i]",($text{"recs_$_[$i]"} || $_[$i]) ),
		      $rnum{$_[$i]} );
		$rv .= &ui_columns_row(\@cols);
		}
	$rv .= &ui_columns_end();
	}
return $rv;
}

