#!/usr/local/bin/perl
# edit_progs.cgi
# A form for editing helper program options

require './squid-lib.pl';
$access{'hprogs'} || &error($text{'eprogs_ecannot'});
&ui_print_header(undef, $text{'eprogs_header'}, "", "edit_progs", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_progs.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eprogs_chpo'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
if ($squid_version < 2) {
	print &opt_input($text{'eprogs_sfp'}, "ftpget_program", $conf,
			 $text{'default'}, 40, &file_chooser_button("ftpget_program"));
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eprogs_fo'}, "ftpget_options", $conf, $text{'default'}, 15);
	}
else {
	print &opt_input($text{'eprogs_fcv'}, "ftp_list_width", $conf,
			 $text{'default'}, 6, $text{'eprogs_c'});
	}
print &opt_input($text{'eprogs_afl'}, "ftp_user", $conf, $text{'default'}, 15);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'eprogs_sdp'}, "cache_dns_program", $conf, $text{'default'}, 40,
		 &file_chooser_button("cache_dns_program"));
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'eprogs_nodp'}, "dns_children", $conf, $text{'default'}, 5);
print &choice_input($text{'eprogs_adtr'}, "dns_defnames", $conf, "off",
		    $text{'yes'}, "on", $text{'no'}, "off");
print "</tr>\n";

if ($squid_version >= 2) {
	print "<tr>\n";
	print &opt_input($text{'eprogs_dsa'}, "dns_nameservers", $conf,
			 $text{'eprogs_fr'}, 35);
	print "</tr>\n";
	}

print "<tr>\n";
print &opt_input($text{'eprogs_ccp'}, "unlinkd_program", $conf,
		 $text{'default'}, 40, &file_chooser_button("unlinkd_program"));
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'eprogs_spp'}, "pinger_program", $conf,
		 $text{'default'}, 40, &file_chooser_button("pinger_program"));
print "</tr>\n";

if ($squid_version >= 2.6) {
	print "<tr>\n";
        print &opt_input($text{'eprogs_crp'}, "url_rewrite_program", $conf,
                         $text{'none'}, 40, &file_chooser_button("url_rewrite_program"));
        print "</tr>\n";

        print "<tr>\n";
        print &opt_input($text{'eprogs_norp'}, "url_rewrite_children", $conf,
                         $text{'default'}, 6);
        print "</tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_input($text{'eprogs_crp'}, "redirect_program", $conf,
			 $text{'none'}, 40, &file_chooser_button("redirect_program"));
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eprogs_norp'}, "redirect_children", $conf,
			 $text{'default'}, 6);
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'></form>\n";

&ui_print_footer("", $text{'eprogs_return'});

