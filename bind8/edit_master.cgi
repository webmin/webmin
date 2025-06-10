#!/usr/local/bin/perl
# edit_master.cgi
# Display options and directives in an existing master zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config, %is_extra);

require './bind8-lib.pl';
&ReadParse();
our $ipv6revzone;
$in{'view'} = 'any' if (!$in{'view'} || $in{'view'} eq '');
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) || &error($text{'master_ecannot'});
&ui_print_header(&zone_subhead($zone), $text{'master_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

my $d = &get_virtualmin_domains($dom);
if ($d && $d->{'alias'}) {
	print &ui_alert_box($text{'master_vminalias'}, 'danger');
	}
elsif ($d) {
	print &ui_alert_box($text{'master_vmin'}, 'warn');
	}

# Find the record types
my (@rcodes, @recs);
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

my $soa;
my %rnum;
if (!$config{'largezones'}) {
	# See what record type we have
	foreach my $c (@rcodes) { $rnum{$c} = 0; }
	foreach my $r (@recs) {
		$rnum{$r->{'type'}}++;
		$rnum{"ALL"}++ if ($r->{'type'} ne "SOA");
		if ($r->{'type'} eq "SOA") { $soa = $r; }
		}
	}
else {
	# Just assume that we have all types
	$soa = 1;
	}

my (@rlinks, @rtitles, @ricons);
if ($config{'show_list'}) {
	# display as list
	my $mid = int((@rcodes+1)/2);
	my @grid = ( );
	push(@grid, &types_table(@rcodes[0..$mid-1]));
	push(@grid, &types_table(@rcodes[$mid..$#rcodes]));
	print &ui_grid_table(\@grid, 2, 100, [ "width=50%", "width=50%" ]);
	}
else {
	# display as icons
	for(my $i=0; $i<@rcodes; $i++) {
		push(@rlinks, "edit_recs.cgi?zone=$in{'zone'}&".
			      "view=$in{'view'}&type=$rcodes[$i]");
		push(@rtitles, ($text{"type_$rcodes[$i]"} || $rcodes[$i]).
			       (%rnum ? " ($rnum{$rcodes[$i]})" : ""));
		push(@ricons, $is_extra{$rcodes[$i]} ?
				"images/extra.gif" : "images/$rcodes[$i].gif");
		}
	&icons_table(\@rlinks, \@rtitles, \@ricons);
	}

# links to forms editing text, soa and zone options
my (@titles, @links, @images);
if ($access{'file'}) {
	# Manually edit zone
	push(@links, "edit_text.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_manual'});
	push(@images, "images/text.gif");
	}
if ($access{'params'}) {
	# SOA values
	push(@links, "edit_soa.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_soa'});
	push(@images, "images/soa.gif");
	}
if ($access{'opts'}) {
	# Zone options in named.conf
	push(@links, "edit_options.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_options'});
	push(@images, "images/options.gif");
	}
if ($access{'findfree'}) {
	# Find free IPs
	push(@links, "find_free.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'findfree_desc'});
	push(@images, "images/findfree.gif");
	}
if ($access{'gen'}) {
	# Generators
	push(@links, "list_gen.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'gen_title'});
	push(@images, "images/gen.gif");
	}
if ($access{'whois'} && &has_command($config{'whois_cmd'}) &&
    $dom !~ /in-addr\.arpa/i) {
	# Whois lookup
	push(@links, "whois.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'master_whois'});
	push(@images, "images/whois.gif");
	}
if ($access{'dnssec'} && &supports_dnssec()) {
	if (&have_dnssec_tools_support()) {
		# DNSSEC Automation
		push(@links, "edit_zonedt.cgi?zone=$in{'zone'}&view=$in{'view'}");
		push(@titles, $text{'dt_enable_title'});
		push(@images, "images/dnssectools.gif");
	}

	# Zone key
	push(@links, "edit_zonekey.cgi?zone=$in{'zone'}&view=$in{'view'}");
	push(@titles, $text{'zonekey_title'});
	push(@images, "images/zonekey.gif");
	}

if (@links) {
	print &ui_hr();
	&icons_table(\@links, \@titles, \@images);
	}

my $apply = $access{'apply'} && &has_ndc();
if (!$access{'ro'} && ($access{'delete'} || $apply)) {
	print &ui_hr();
	print &ui_buttons_start();

	if ($apply) {
		# Show button to freeze
		print &ui_buttons_row(
			"freeze_zone.cgi", $text{'master_freeze'},
			$text{'master_freezemsg2'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'})
			);

		# Show button to un-freeze
		print &ui_buttons_row(
			"unfreeze_zone.cgi", $text{'master_unfreeze'},
			$text{'master_unfreezemsg2'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'})
			);
		}

	# Show button to check records
	if (&supports_check_zone()) {
		print &ui_buttons_row(
			"check_zone.cgi", $text{'master_checkzone'},
			$text{'master_checkzonemsg'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'})
			);
		}

	# Move zone button
	my $conf = &get_config();
	print &move_zone_button($conf, $zone->{'viewindex'}, $in{'zone'});

	# Convert to slave zone
	if ($access{'slave'}) {
		print &ui_buttons_row("convert_master.cgi",
			$text{'master_convert'},
			$text{'master_convertdesc'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'}));
		}

	if ($access{'delete'}) {
		# Show button to delete zome
		print &ui_buttons_row(
			"delete_zone.cgi", $text{'master_del'},
			$text{'master_delmsg'}." ".
			($dom !~ /in-addr\.arpa/i &&
			 $dom !~ /\.$ipv6revzone/i ? $text{'master_delrev'}
						   : ""),
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'})
			);
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
		%rnum ? ( $text{'master_records'} ) : ( )
		], 100);
	for(my $i=0; $_[$i]; $i++) {
		my @cols = ( &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$_[$i]", ($text{"recs_$_[$i]"} || $_[$i]) ) );
		if (%rnum) {
			push(@cols, $rnum{$_[$i]});
			}
		$rv .= &ui_columns_row(\@cols);
		}
	$rv .= &ui_columns_end();
	}
return $rv;
}

