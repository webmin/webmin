#!/usr/local/bin/perl
# Show a form to edit one port forward

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text);
&ReadParse();

# Get the zone and rule
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
my ($mode, $ports, $proto, $port, $portlow, $porthigh,
    $dstmode, $dstports, $dstport, $dstportlow, $dstporthigh, $dstaddr);
if (!$in{'new'}) {
	&ui_print_header(undef, $text{'forward_edit'}, "");
	($ports, $proto, $dstports, $dstaddr) = split(/\//, $in{'id'});
	if ($ports =~ /^(\d+)\-(\d+)$/) {
		$mode = 1;
		($portlow, $porthigh) = ($1, $2);
		}
	else {
		$mode = 0;
		$port = $ports;
		}
	if ($dstports =~ /^(\d+)\-(\d+)$/) {
		$dstmode = 1;
		($dstportlow, $dstporthigh) = ($1, $2);
		}
	elsif ($dstports) {
		$dstmode = 0;
		$dstport = $dstports;
		}
	else {
		$dstmode = 2;
		}
	}
else {
	&ui_print_header(undef, $text{'forward_create'}, "");
	$mode = 0;
	$dstmode = 0;
	$proto = "tcp";
	}

print &ui_form_start("save_forward.cgi", "post");
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("id", $in{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'forward_header'}, undef, 2);

# Zone name
print &ui_table_row($text{'forward_zone'},
		    "<tt>".&html_escape($zone->{'name'})."</tt>");

# Port number or range
print &ui_table_row($text{'forward_port'},
	&ui_radio_table("mode", $mode, 
			[ [ 0, $text{'port_mode0'},
			    &ui_textbox("port", $port, 6) ],
			  [ 1, $text{'port_mode1'},
			    &ui_textbox("portlow", $portlow, 6)." - ".
			    &ui_textbox("porthigh", $porthigh, 6) ] ]));

# Protocol name
print &ui_table_row($text{'port_proto'},
	&ui_select("proto", $proto,
		   [ [ "tcp", "TCP" ],
		     [ "udp", "UDP" ] ], 1, 0, 1));

# Destination port number or range
print &ui_table_row($text{'forward_dstport'},
	&ui_radio_table("dstmode", $dstmode, 
			[ [ 0, $text{'port_mode0'},
			    &ui_textbox("dstport", $dstport, 6) ],
			  [ 1, $text{'port_mode1'},
			    &ui_textbox("dstportlow", $dstportlow, 6)." - ".
			    &ui_textbox("dstporthigh", $dstporthigh, 6) ],
			  [ 2, $text{'port_mode2'} ] ]));

# Destination address
print &ui_table_row($text{'forward_dstaddr'},
	&ui_opt_textbox("dstaddr", $dstaddr, 40, $text{'forward_dstlocal'}));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("index.cgi?zone=".&urlize($zone->{'name'}),
	         $text{'index_return'});
