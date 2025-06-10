#!/usr/local/bin/perl
# Show all firewalld rules and zones

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&ReadParse();
if ($in{'addzone'}) {
	# Redirect to zone creation form
	&redirect("zone_form.cgi?zone=".&urlize($in{'zone'}));
	return;
	}
if ($in{'delzone'}) {
	# Redirect to zone deletion form
	&redirect("delete_zone.cgi?zone=".&urlize($in{'zone'}));
	return;
	}
if ($in{'defzone'}) {
	# Make a zone the default
	&redirect("default_zone.cgi?zone=".&urlize($in{'zone'}));
	return;
	}
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

# Is firewalld working?
my $err = &check_firewalld();
if ($err) {
	&ui_print_endpage(&text('index_cerr', $err));
	return;
	}

my @zones;
my $zone;

# Is FirewallD running if not, show start button
my $ok = &is_firewalld_running();
if ($ok) {
	# Get rules and zones
	@zones = &list_firewalld_zones();
	@zones || &error($text{'index_ezones'});
	if ($in{'zone'}) {
		($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
		}
	else {
		($zone) = grep { $_->{'default'} } @zones;
		}
	$zone ||= $zones[0];
	my ($azone);
	eval {
		local $main::error_must_die = 1;
		my @azones = &list_firewalld_zones(1);
		($azone) = grep { $_->{'name'} eq $zone->{'name'} } @azones;
		};

	# Show zone selector
	print &ui_form_start("index.cgi");
	print "$text{'index_zone'}&nbsp; ",
	      &ui_select("zone", $zone->{'name'},
			 [ map { [ $_->{'name'},
				   $_->{'name'}.($_->{'default'} ? ' (default)' : '') ]}
			       @zones ], 1, 0, 0, 0,
			 "onChange='form.submit()'")," ",
	      &ui_submit($text{'index_zonedef'}, "defzone")," ",
	      &ui_submit($text{'index_zonedel'}, "delzone")," &nbsp; ",
	      &ui_submit($text{'index_zoneadd'}, "addzone")," ",
	      "<p>\n";
	print &ui_form_end();

	# Show allowed ports and services in this zone
	my @links = ( &ui_link("edit_port.cgi?new=1&zone=".&urlize($zone->{'name'}),
			       $text{'index_padd'}),
		      &ui_link("edit_serv.cgi?new=1&zone=".&urlize($zone->{'name'}),
	                       $text{'index_sadd'}),
		      &ui_link("edit_forward.cgi?new=1&zone=".&urlize($zone->{'name'}),
	                       $text{'index_fadd'}),
		      &ui_link("edit_manual.cgi", $text{'index_manual'}),
		    );
	if (@{$zone->{'services'}} || @{$zone->{'ports'}}) {
		my @tds = ( "width=5" );
		unshift(@links, &select_all_link("d", 1),
				&select_invert_link("d", 1));
		print &ui_form_start("delete_rules.cgi", "post");
		print &ui_hidden("zone", $zone->{'name'});
		print &ui_links_row(\@links);
		print &ui_columns_start([ "", $text{'index_type'}, $text{'index_port'},
					  $text{'index_proto'} ], 100, 0, \@tds);
		foreach my $s (@{$zone->{'services'}}) {
			my $url = "edit_serv.cgi?id=".&urlize($s).
				  "&zone=".&urlize($zone->{'name'});
			my $sportsprotos = &list_firewalld_service_desc($s);
			my $sport = $sportsprotos->{'ports'};
			my $sprotocols = $sportsprotos->{'protocols'};
			$sport = " ($sport)" if ($sport);
			print &ui_checked_columns_row([
				&ui_link($url, $text{'index_tservice'}),
				&ui_link($url, "$s$sport"),
				$sprotocols || "",
				], \@tds, "d", "service/".$s);
			}
		foreach my $p (@{$zone->{'ports'}}) {
			my $url = "edit_port.cgi?id=".&urlize($p).
				  "&zone=".&urlize($zone->{'name'});
			my ($port, $proto) = split(/\//, $p);
			print &ui_checked_columns_row([
				&ui_link($url, $text{'index_tport'}),
				&ui_link($url, $port),
				uc($proto),
				], \@tds, "d", "port/".$p);
			}
		foreach my $f (@{$zone->{'forward-ports'}}) {
			my ($port, $proto, $dstport, $dstaddr) =
				&parse_firewalld_forward($f);
			my $p = join("/", $port, $proto, $dstport, $dstaddr);
			my $url = "edit_forward.cgi?id=".&urlize($p).
				  "&zone=".&urlize($zone->{'name'});
			print &ui_checked_columns_row([
				&ui_link($url, $text{'index_tforward'}),
				&ui_link($url, $port),
				&ui_link($url, uc($proto)),
				], \@tds, "d", "forward/".$p);
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ undef, $text{'index_delete'} ] ]);
		}
	else {
		print "$text{'index_none'}<p>\n";
		print &ui_links_row(\@links);
		}

	if ($azone) {
		# Show interfaces for this zone
		print &ui_form_start("save_ifaces.cgi");
		print &ui_hidden("zone", $zone->{'name'});
		print "<br>$text{'index_ifaces'}&nbsp;\n";
		my %zifcs = map { $_, 1 } &unique(@{$azone->{'interfaces'}},
						  @{$zone->{'interfaces'}});
		print &ui_radio("iface_def", %zifcs ? 0 : 1,
				[ [ 1, $text{'index_ifaces_def'} ],
				  [ 0, $text{'index_ifaces_sel'} ] ]),"\n";
		foreach my $i (&list_system_interfaces()) {
			print &ui_checkbox("iface", $i, $i, $zifcs{$i}),"\n";
			}
		print &ui_submit($text{'index_ifaces_apply'});
		print &ui_form_end();
		}

	# Allow/block given IP
	my $blockip_placeholder =
		&text('index_blockip_placeholder', '1.2.3.4', '2001:db8::1/64');
	foreach my $action (['allow', $text{'index_allowip_go'},
			     $text{'index_allowip_permanent'}],
			    ['block', $text{'index_blockip_go'},
			     $text{'index_blockip_permanent'}]) {
		print "<br>".&ui_form_start("manage_ip.cgi");
		print &ui_hidden("zone", $zone->{'name'});
		print &ui_submit($action->[1], $action->[0]),
			&ui_textbox("ip", undef, 21, undef, undef,
				"placeholder='$blockip_placeholder'")."&nbsp;".
			&ui_checkbox("permanent", 1, $action->[2], 1);
		print &ui_form_end();
		}
	print &ui_form_end();
	print &ui_hr();
	
	# Show start/apply buttons
	print &ui_buttons_start();
	print &ui_buttons_row("list_rules.cgi", $text{'index_listrules'},
		      &text("index_listrules_restartdesc",
		            "<tt>".$zone->{'name'}."</tt>"),
		      [ [ "zone", $zone->{'name'} ] ]);
	print &ui_buttons_row("restart.cgi", $text{'index_restart_firewalld'},
			      $text{'index_restart_firewallddesc'},
			      [ [ "zone", $zone->{'name'} ] ]);
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopdesc'},
			      [ [ "zone", $zone->{'name'} ] ]);
	}
else {
	print &ui_alert_box($text{'index_downrules'}, 'warn');
	}

# Show Start and disable/enabled at boot button
if (!$ok) {
	print &ui_buttons_start();
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startdesc'},
			      [ [ "zone", $zone->{'name'} ] ]);
	}

# Enable at boot
&foreign_require("init");
my $st = &init::action_status($config{'init_name'});
if ($st) {
	my $atboot = $st == 2 ? 1 : 0;
	print &ui_buttons_row("bootup.cgi", $text{'index_bootup'},
			      $text{'index_bootupdesc'},
			      [ [ "zone", $zone->{'name'} ] ],
			      &ui_yesno_radio("boot", $atboot));
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});
