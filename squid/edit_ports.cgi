#!/usr/local/bin/perl
# edit_ports.cgi
# A form for editing ports and other networking options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ui_print_header(undef, $text{'eports_header'}, "", "edit_ports", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_ports.cgi", "post");
print &ui_table_start($text{'eports_pano'}, "width=100%", 4);

if ($squid_version >= 2.3) {
	# Display table of normal ports
	print &ui_table_row($text{'eports_paap'},
		&ports_table("http_port"), 3);

	if ($squid_version >= 2.5) {
		# Display table of SSL ports
		print &ui_table_row($text{'eports_ssl'},
			&ports_table("https_port"), 3);
		}
	print &opt_input($text{'eports_ip'}, "icp_port", 
				$conf, $text{'default'}, 6);
	}
else {
	# Just show single-port inputs
	print &opt_input($text{'eports_pp'}, "http_port", 
				$conf, $text{'default'}, 6);
	print &opt_input($text{'eports_ip'}, "icp_port", 
				$conf, $text{'default'}, 6);
	print &opt_input($text{'eports_ita'}, "tcp_incoming_address",
			 $conf, $text{'eports_a'}, 15);
	}

print &opt_input($text{'eports_ota'}, "tcp_outgoing_address",
		 $conf, $text{'eports_a'}, 15);

print &opt_input($text{'eports_oua'}, "udp_outgoing_address",
		 $conf, $text{'eports_a'}, 15);
print &opt_input($text{'eports_iua'}, "udp_incoming_address",
		 $conf, $text{'eports_a'}, 15);

print &address_input($text{'eports_mg'}, "mcast_groups", $conf, 0);
print &opt_input($text{'eports_trb'}, "tcp_recv_bufsize", $conf,
		 $text{'eports_od'}, 6);

if ($squid_version >= 2.6) {
	print &choice_input($text{'eports_checkhost'}, "check_hostnames",
			    $conf, "on", $text{'yes'}, "on", $text{'no'},"off");
	print &choice_input($text{'eports_underscore'}, "allow_underscore",
			    $conf, "on", $text{'yes'}, "on", $text{'no'},"off");
	}

if ($squid_version >= 2.5) {
	print &choice_input($text{'eports_unc'}, "ssl_unclean_shutdown",
			    $conf, "off", $text{'on'},"on", $text{'off'},"off");
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'eports_return'});

# ports_table(name)
sub ports_table
{
my ($name) = @_;
my @ports;
my @opts;
foreach my $p (&find_config($name, $conf)) {
	foreach my $v (@{$p->{'values'}}) {
		if ($v =~ /^(\S+):\d+$/ || $v =~ /^\d+$/) {
			push(@ports, $v);
			}
		else {
			$opts[$#ports] ||= [];
			push(@{$opts[$#ports]}, $v);
			}
		}
	}
my $rv = &ui_radio($name."_ports_def", @ports ? 0 : 1,
		   [ [ 1, $text{'eports_def'} ],
		     [ 0, $text{'eports_sel'} ] ])."<br>\n";
$rv .= &ui_columns_start([ $text{'eports_p'}, $text{'eports_hia'},
			   $squid_version >= 2.5 ? ( $text{'eports_opts'} )
						 : ( ) ]);
my $i = 0;
foreach my $p (@ports, '') {
	$opts[$i] ||= [];
	$rv .= &ui_columns_row([
		&ui_textbox($name."_port_".$i, $p =~ /(\d+)$/ ? $1 : '', 6),
		&ui_radio($name."_addr_def_".$i,
			  $p =~ /:/ ? 0 : 1,
			  [ [ 1, $text{'eports_all'} ],
			    [ 0, &ui_textbox($name."_addr_".$i,
				     $p =~ /^\[(\S+)\]:/ ||
				     $p =~ /^(\S+):/ ? $1 : '', 20) ] ]),
		$squid_version >= 2.5 ?
			( &ui_textbox($name."_opts_$i",
				      join(" ", @{$opts[$i]}), 20) ) : ( ),
		]);
	$i++;
	}
$rv .= &ui_columns_end();
return $rv;
}

