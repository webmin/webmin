#!/usr/local/bin/perl
# edit_misc.cgi
# A form for edit misc options

require './squid-lib.pl';
$access{'miscopt'} || &error($text{'emisc_ecannot'});
&ui_print_header(undef, $text{'emisc_header'}, "", "edit_misc", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_misc.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'emisc_mo'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
print &opt_input($text{'emisc_sdta'}, "dns_testnames", $conf,
		 $text{'default'}, 40);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'emisc_slr'}, "logfile_rotate", $conf,
		 $text{'default'}, 6);
print &opt_input($text{'emisc_dd'}, "append_domain", $conf, $text{'none'}, 10);
print "</tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &opt_input($text{'emisc_sp'}, "ssl_proxy", $conf, $text{'none'}, 15);
	print &opt_input($text{'emisc_nghp'}, "passthrough_proxy",
			 $conf, $text{'none'}, 15);
	print "</tr>\n";
	}

print "<tr>\n";
print &opt_input($text{'emisc_emt'}, "err_html_text", $conf, $text{'none'}, 40);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'emisc_pcs'}, "client_db", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
print &choice_input($text{'emisc_xffh'}, "forwarded_for", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'emisc_liq'}, "log_icp_queries", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
print &opt_input($text{'emisc_mdh'}, "minimum_direct_hops", $conf,
		 $text{'default'}, 6);
print "</tr>\n";

print "<tr>\n";
print &choice_input($text{'emisc_kmffu'}, "memory_pools", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
if ($squid_version >= 2) {
	print &opt_bytes_input($text{'emisc_aomtk'}, "memory_pools_limit",
			       $conf, $text{'emisc_u'}, 6);
	}
print "</tr>\n";

print "<tr>\n";
if ($squid_version >= 2.2 && $squid_version < 2.5) {
	foreach $a (&find_config("anonymize_headers", $conf)) {
		@ap = @{$a->{'values'}};
		$anon = shift(@ap);
		push(@anon, @ap);
		}
	print "<td valign=top><b>$text{'emisc_htpt'}</b></td> ",
	      "<td colspan=3>\n";
	printf "<input type=radio name=anon_mode value=0 %s> $text{'emisc_ah'}<br>\n",
		$anon ? "" : "checked";
	printf "<input type=radio name=anon_mode value=1 %s> $text{'emisc_oh'}\n",
		$anon eq "allow" ? "checked" : "";
	printf "<input name=anon_allow size=50 value='%s'><br>\n",
		$anon eq "allow" ? join(" ", @anon) : "";
	printf "<input type=radio name=anon_mode value=2 %s> $text{'emisc_ae'}\n",
		$anon eq "deny" ? "checked" : "";
	printf "<input name=anon_deny size=50 value='%s'>\n",
		$anon eq "deny" ? join(" ", @anon) : "";
	print "</td> </tr> <tr>\n";
	}
elsif ($squid_version < 2.2) {
	print &choice_input($text{'emisc_a'}, "http_anonymizer", $conf,
			    "off", $text{'emisc_off'}, "off", 
				$text{'emisc_std'}, "standard",
			    $text{'emisc_par'}, "paranoid");
	}
print &opt_input($text{'emisc_fua'}, "fake_user_agent", $conf, $text{'none'}, 15);

print "</tr><tr>\n";
if ($squid_version < 2.6) {
	$host = &find_value("httpd_accel_host", $conf);
	print "<td><b>$text{'emisc_hah'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=accel value=0 %s> %s\n",
		$host ? "" : "checked", $text{'emisc_none'};
	printf "<input type=radio name=accel value=1 %s> %s\n",
		$host eq "virtual" ? "checked" : "", $text{'emisc_virtual'};
	printf "<input type=radio name=accel value=2 %s>\n",
		$host eq "virtual" || !$host ? "" : "checked";
	printf "<input name=httpd_accel_host size=50 value='%s'></td>\n",
		$host eq "virtual" ? "" : $host;
	print "</tr><tr>\n";
	print &opt_input($text{'emisc_hap'}, "httpd_accel_port", $conf,
			 $text{'emisc_none'}, 10);
	if ($squid_version >= 2.5) {
		print &choice_input($text{'emisc_hash'}, "httpd_accel_single_host", 
				  $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
		}
	print "</tr><tr>\n";
	print &choice_input($text{'emisc_hawp'}, "httpd_accel_with_proxy",
			  $conf, "off", $text{'on'}, "on", $text{'off'}, "off");
	print &choice_input($text{'emisc_hauhh'}, "httpd_accel_uses_host_header", 
			  $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
	print "</tr><tr>\n";
	}

if ( $squid_version >= 2.3) {
        print &opt_input($text{'emisc_wccprtr'}, "wccp_router", $conf,
                         $text{'default'}, 35);
        print "</tr><tr>\n";
        print &opt_input($text{'emisc_wccpin'}, "wccp_incoming_address",
			 $conf, $text{'default'}, 35);
        print "</tr><tr>\n";
        print &opt_input($text{'emisc_wccpout'}, "wccp_outgoing_address",
			 $conf, $text{'default'}, 35);
        print "</tr><tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'emisc_return'});

