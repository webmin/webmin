#!/usr/local/bin/perl
# index.cgi
# Display ADSL configuration options
# XXX new-style ADSL config in redhat 7.2 and above!
#	XXX effects start/stop and bootup as well

require './adsl-client-lib.pl';
$vers = &get_pppoe_version(\$out);
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("pppoe", "man", "doc", "google"), undef, undef,
	$vers ? &text('index_version', $vers) : undef);

if (!$vers) {
	# Not installed
	print "<p>",&text('index_eadsl', "<tt>$config{'pppoe_cmd'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	}
elsif (!($conf = &get_config())) {
	# Missing config file
	if ($config{'conf_style'} == 0) {
		# Just give up
		print "<p>",
		      &text('index_econfig', "<tt>$config{'pppoe_conf'}</tt>",
		      "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		}
	else {
		# On redhat systems, the file needs to be created by this
		# module :-(
		print "<p>",&text('index_esetup',
			"<tt>$config{'pppoe_conf'}</tt>"),"<p>\n";
		print "<center><form action=setup.cgi>\n";
		print "<input type=submit value='$text{'index_setup'}'>\n";
		print "</form></center>\n";
		}
	}
elsif (&find("TYPE", $conf) =~ /modem/i) {
	# For a modem on a redhat system
	$config{'pppoe_conf'} =~ /^(.*)\//;
	print "<p>",&text('index_emodem', "<tt>$1</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	}
else {
	# Show configuration form
	$conf = &get_config();
	print "$text{'index_desc'}<p>\n";
	print "<form action=save.cgi method=post>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	# Show network interface field
	&foreign_require("net", "net-lib.pl");
	$eth = &find("ETH", $conf);
	print "<tr> <td><b>",&hlink($text{'index_eth'}, "eth"),"</b></td>\n";
	@ifcs = &net::active_interfaces(1);
	print "<td><select name=eth>\n";
	$found = !$eth;
	foreach $i (@ifcs) {
		next if ($i->{'fullname'} !~ /^eth(\d+)$/);
		printf "<option value='%s' %s>%s\n",
			$i->{'name'}, $eth eq $i->{'name'} ? "selected" : "",
			$i->{'name'},
			"</option>";
		$found++ if ($eth eq $i->{'name'});
		}
	printf "<option value='' %s>%s\n",
		$found ? "" : "selected", $text{'index_other'},
		"</option>";
	print "</select>\n";
	printf "<input name=other size=6 value='%s'></td>\n",
		$found ? "" : $eth;

	# Show on-demand field
	$demand = &find("DEMAND", $conf);
	print "<td><b>",&hlink($text{'index_demand'},"demand"),"</b></td>\n";
	printf "<td nowrap><input type=radio name=demand value=yes %s> %s\n",
		$demand !~ /^\d+$/i ? "" : "checked", $text{'index_timeout'};
	printf "<input name=timeout value='%s' size=4>\n",
		$demand !~ /^\d+$/i ? "" : $demand;
	printf "<input type=radio name=demand value=no %s> %s</td> </tr>\n",
		$demand !~ /^\d+$/i ? "checked" : "", $text{'no'};

	# Show username field
	$user = &find("USER", $conf);
	print "<tr> <td><b>",&hlink($text{'index_user'},"user"),"</b></td>\n";
	printf "<td><input name=user size=20 value='%s'></td>\n",
		$user;

	# Show password field (from pap-secrets)
	($sec) = grep { $_->{'client'} eq $user } &list_secrets();
	print "<td><b>",&hlink($text{'index_sec'},"sec"),"</b></td>\n";
	printf "<td><input type=password name=sec size=20 value='%s'></td> </tr>\n",
		$sec->{'secret'};

	# Show DNS config buttons
	$dns = &find("USEPEERDNS", $conf) || &find("PEERDNS", $conf);
	print "<tr> <td><b>",&hlink($text{'index_dns'}, "dns"),"</b></td>\n";
	printf "<td><input type=radio name=dns value=yes %s> %s\n",
		$dns =~ /yes/i ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=dns value=no %s> %s</td>\n",
		$dns =~ /yes/i ? "" : "checked", $text{'no'};

	# Show connect timeout field
	$connect = &find("CONNECT_TIMEOUT", $conf);
	print "<td><b>",&hlink($text{'index_connect'},"connect"),"</b></td>\n";
	printf "<td nowrap><input type=radio name=connect_def value=1 %s> %s\n",
		$connect == 0 ? "checked" : "", $text{'index_forever'};
	printf "<input type=radio name=connect_def value=0 %s>\n",
		$connect == 0 ? "" : "checked";
	printf "<input name=connect size=4 value='%s'> %s</td> </tr>\n",
		$connect == 0 ? "" : $connect, $text{'index_secs'};

	# Show MSS field
	$mss = &find("CLAMPMSS", $conf);
	print "<tr> <td><b>",&hlink($text{'index_mss'},"mss"),"</b></td>\n";
	printf "<td nowrap><input type=radio name=mss value=yes %s> %s\n",
		$mss =~ /no/i ? "" : "checked", $text{'index_psize'};
	printf "<input name=psize value='%s' size=5> %s\n",
		$mss =~ /no/i ? "" : $mss, $text{'index_bytes'};
	printf "<input type=radio name=mss value=no %s> %s</td>\n",
		$mss =~ /no/i ? "checked" : "", $text{'no'};

	# Show firewall menu
	$fw = &find("FIREWALL", $conf);
	$fw ||= "NONE";
	if ($fw ne "NONE") {
		print "<td><b>",&hlink($text{'index_fw'},"fw"),"</b></td>\n";
		print "<td><select name=fw>\n";
		foreach $f ('NONE', 'STANDALONE', 'MASQUERADE') {
			printf "<option value=%s %s>%s\n",
				$f, lc($f) eq lc($fw) ? "selected" : "",
				$text{'index_fw_'.lc($f)},
				"</option>";
			}
		print "</select></td> </tr>\n";
		}
	else {
		print "</tr>\n";
		}

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'index_save'}'></form>\n";

	# Show connected/disconnect buttons
	print &ui_hr();
	print &ui_buttons_start();
	local ($dev, $ip) = &get_adsl_ip();
	if ($ip) {
		# Offer to shut down
		print &ui_buttons_row("stop.cgi", $text{'index_stop'},
				      &text('index_stopdesc', "<tt>$ip</tt>",
					    "<tt>$config{'stop_cmd'}</tt>"));
		}
	elsif ($dev eq "demand") {
		# Offer to cancel on-demand connection
		print &ui_buttons_row("stop.cgi", $text{'index_cdemand'},
				      &text('index_cdemanddesc',
					    "<tt>$config{'stop_cmd'}</tt>"));
		}
	elsif ($dev) {
		# Offer to cancel connect
		print &ui_buttons_row("stop.cgi", $text{'index_cancel'},
				      &text('index_canceldesc',
					    "<tt>$config{'stop_cmd'}</tt>"));
		}
	else {
		# Offer to start up
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      &text('index_startdesc',
					    "<tt>$config{'start_cmd'}</tt>"));
		}

	# Show boot-time button
	if ($config{'conf_style'} == 1 && ($onboot = find("ONBOOT", $conf))) {
		# Offer to turn on/off starting at boot
		print &ui_buttons_row("rbootup.cgi", $text{'index_boot'},
				      $text{'index_bootdesc'}, undef,
				      &ui_yesno_radio("onboot",
						 $onboot =~ /yes/i ? 1 : 0));
		}
	elsif (&foreign_check("init")) {
		# Offer to enable/disable init script
		&foreign_require("init", "init-lib.pl");
		$boot = &init::action_status("adsl");
		if ($boot > 0) {
			print &ui_buttons_row("bootup.cgi", $text{'index_boot'},
					      $text{'index_bootdesc'}, undef,
					      &ui_yesno_radio("boot",
							 $boot == 2 ? 1 : 0));
			}
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

