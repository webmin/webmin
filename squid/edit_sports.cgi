#!/usr/local/bin/perl
# edit_sports.cgi
# A form for editing simple networking options

require './squid-lib.pl';
$access{'portsnets'} || &error($text{'eports_ecannot'});
&ui_print_header(undef, $text{'eports_header'}, "", "", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_sports.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eports_pano'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
if ($squid_version >= 2.3) {
	print "<td valign=top><b>$text{'eports_paap'}</b></td>\n";
	print "<td colspan=3><table border>\n";
	print "<tr $tb> <td><b>$text{'eports_p'}</b></td>\n",
	      "<td><b>$text{'eports_hia'}</b></td> </tr>\n";
	foreach $p (&find_config('http_port', $conf)) {
		push(@ports, @{$p->{'values'}});
		}
	$i = 0;
	foreach $p (@ports, '') {
		print "<tr $cb>\n";
		printf "<td><input name=port_$i size=6 value='%s'></td> <td>\n",
			$p =~ /(\d+)$/ ? $1 : '';
		printf "<input type=radio name=addr_def_$i value=1 %s> All\n",
			$p =~ /:/ ? '' : 'checked';
		printf "<input type=radio name=addr_def_$i value=0 %s>\n",
			$p =~ /:/ ? 'checked' : '';
		printf "<input name=addr_$i size=20 value='%s'></td>\n",
			$p =~ /^(\S+):/ ? $1 : '';
		print "</tr>\n";
		$i++;
		}

	print "</table></td></tr>\n";
	}
else {
	print &opt_input($text{'eports_pp'}, "http_port", 
				$conf, $text{'default'}, 6);
	print &opt_input($text{'eports_ita'}, "tcp_incoming_address",
			 $conf, $text{'eports_a'}, 15);
	print "</tr>\n";
	}

print "<tr>\n";
print &opt_input($text{'emisc_sdta'}, "dns_testnames", $conf,
		 $text{'default'}, 40);
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "</tr><tr>\n";
print &opt_input($text{'emisc_hah'}, "httpd_accel_host", $conf,
                 $text{'default'}, 50);
print "</tr><tr>\n";
print &opt_input($text{'emisc_hap'}, "httpd_accel_port", $conf,
                 $text{'default'}, 10);
print "</tr><tr>\n";
print &choice_input($text{'emisc_hawp'}, "httpd_accel_with_proxy",
                  $conf, "off", $text{'on'}, "on", $text{'off'}, "off");
print &choice_input($text{'emisc_hauhh'}, "httpd_accel_uses_host_header", 
                  $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
print "</tr><tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'eports_return'});

