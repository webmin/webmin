#!/usr/local/bin/perl
# edit_ports.cgi
# A form for editing ports and other networking options

require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ui_print_header(undef, $text{'eports_header'}, "", "edit_ports", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_ports.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eports_pano'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
if ($squid_version >= 2.3) {
	# Display table of normal ports
	print "<td valign=top><b>$text{'eports_paap'}</b></td><td colspan=3>\n";
	&ports_table("http_port");
	print "</table></td></tr>\n";

	if ($squid_version >= 2.5) {
		# Display table of SSL ports
		print "<tr> <td valign=top><b>$text{'eports_ssl'}</b></td><td colspan=3>\n";
		&ports_table("https_port");
		print "</table></td></tr>\n";
		}
	print "<tr>\n";
	print &opt_input($text{'eports_ip'}, "icp_port", 
				$conf, $text{'default'}, 6);
	}
else {
	# Just show single-port inputs
	print &opt_input($text{'eports_pp'}, "http_port", 
				$conf, $text{'default'}, 6);
	print &opt_input($text{'eports_ip'}, "icp_port", 
				$conf, $text{'default'}, 6);
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eports_ita'}, "tcp_incoming_address",
			 $conf, $text{'eports_a'}, 15);
	}

print &opt_input($text{'eports_ota'}, "tcp_outgoing_address",
		 $conf, $text{'eports_a'}, 15);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'eports_oua'}, "udp_outgoing_address",
		 $conf, $text{'eports_a'}, 15);
print &opt_input($text{'eports_iua'}, "udp_incoming_address",
		 $conf, $text{'eports_a'}, 15);
print "</tr>\n";

print "<tr>\n";
print &address_input($text{'eports_mg'}, "mcast_groups", $conf, 0);
print &opt_input($text{'eports_trb'}, "tcp_recv_bufsize", $conf,
		 $text{'eports_od'}, 6);
print "</tr>\n";

if ($squid_version >= 2.6) {
	print "<tr>\n";
	print &choice_input($text{'eports_checkhost'}, "check_hostnames",
			    $conf, "on", $text{'yes'}, "on", $text{'no'},"off");
	print &choice_input($text{'eports_underscore'}, "allow_underscore",
			    $conf, "on", $text{'yes'}, "on", $text{'no'},"off");
	print "</tr>\n";
	}

if ($squid_version >= 2.5) {
	print "<tr>\n";
	print &choice_input($text{'eports_unc'}, "ssl_unclean_shutdown",
			    $conf, "off", $text{'on'},"on", $text{'off'},"off");
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'buttsave'}></form>\n";

&ui_print_footer("", $text{'eports_return'});

# ports_table(name)
sub ports_table
{
local ($p, $i, @ports, @opts);
foreach $p (&find_config($_[0], $conf)) {
	foreach $v (@{$p->{'values'}}) {
		if ($v =~ /^(\S+):\d+$/ || $v =~ /^\d+$/) {
			push(@ports, $v);
			}
		else {
			push(@{$opts[$#ports]}, $v);
			}
		}
	}
printf "<input type=radio name=$_[0]_ports_def value=1 %s> %s\n",
	@ports ? "" : "checked", $text{'eports_def'};
printf "<input type=radio name=$_[0]_ports_def value=0 %s> %s<br>\n",
	@ports ? "checked" : "", $text{'eports_sel'};
print "<table border>\n";
print "<tr $tb> <td><b>$text{'eports_p'}</b></td>\n",
      "<td><b>$text{'eports_hia'}</b></td> ",
      ($squid_version >= 2.5 ? "<td><b>$text{'eports_opts'}</b></td> "
			     : ""),"</tr>\n";
$i = 0;
foreach $p (@ports, '') {
	print "<tr $cb>\n";
	printf "<td><input name=$_[0]_port_$i size=6 value='%s'></td> <td>\n",
		$p =~ /(\d+)$/ ? $1 : '';
	printf "<input type=radio name=$_[0]_addr_def_$i value=1 %s> All\n",
		$p =~ /:/ ? '' : 'checked';
	printf "<input type=radio name=$_[0]_addr_def_$i value=0 %s>\n",
		$p =~ /:/ ? 'checked' : '';
	printf "<input name=$_[0]_addr_$i size=20 value='%s'></td>\n",
		$p =~ /^\[(\S+)\]:/ || $p =~ /^(\S+):/ ? $1 : '';
	if ($squid_version >= 2.5) {
		# Show port options
		printf "<td><input name=$_[0]_opts_$i size=40 value='%s'></td>\n",
			join(" ", @{$opts[$i]});
		}
	print "</tr>\n";
	$i++;
	}
}

