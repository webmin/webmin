#!/usr/local/bin/perl
# edit_admin.cgi
# A form for editing admin options

require './squid-lib.pl';
$access{'admopts'} || &error($text{'eadm_ecannot'});
&ui_print_header(undef, $text{'eadm_header'}, "", "edit_admin", 0, 0, 0, &restart_button());
$conf = &get_config();

print "<form action=save_admin.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'eadm_aao'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	$v = &find_config("cache_effective_user", $conf);
	print "<td><b>$text{'eadm_runasuu'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=effective_def value=1 %s> $text{'eadm_nochange'}\n",
		$v ? "" : "checked";
	printf "&nbsp;<input type=radio name=effective_def value=0 %s>\n",
		$v ? "checked" : "";
	print $text{'eadm_user'} ,&unix_user_input("effective_u",
				       $v->{'values'}->[0]),"\n";
	print $text{'eadm_group'} ,&unix_group_input("effective_g",
					 $v->{'values'}->[1]),"\n";
	print "</td> </tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_input($text{'eadm_runasuu'}, "cache_effective_user", $conf,
			 $text{'eadm_nochange'}, 8,
			 &user_chooser_button("cache_effective_user", 0));
	print &opt_input($text{'eadm_runasug'}, "cache_effective_group", $conf,
			 $text{'eadm_nochange'}, 8,
			 &group_chooser_button("cache_effective_group", 0));
	print "</tr>\n";
	}

print "<tr>\n";
print &opt_input($text{'eadm_cmemail'}, "cache_mgr",
		 $conf, $text{'eadm_default'}, 35);
print "</tr>\n";

print "<tr>\n";
print &opt_input($text{'eadm_vhost'}, "visible_hostname",
		 $conf, $text{'eadm_auto'}, 35);
print "</tr>\n";

if ($squid_version < 2) {
	print "<tr>\n";
	print &opt_input($text{'eadm_annto'}, "announce_to",
			 $conf, $text{'eadm_default'}, 40);
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eadm_every'}, "cache_announce", $conf,
			 $text{'eadm_never'}, 6, "hours");
	print "</tr>\n";
	}
else {
	print "<tr>\n";
	print &opt_input($text{'eadm_uniq'}, "unique_hostname",
			 $conf, $text{'eadm_auto'}, 35);
	print "</tr>\n";

	if ($squid_version >= 2.4) {
		print "<tr>\n";
		print &opt_input($text{'eadm_haliases'}, "hostname_aliases",
				 $conf, $text{'eadm_none'}, 35);
		print "</tr>\n";
		}

	print "<tr>\n";
	print &opt_input($text{'eadm_cah'}, "announce_host", $conf,
			 $text{'eadm_default'}, 20);
	print &opt_input($text{'eadm_cap'}, "announce_port", $conf,
			 $text{'eadm_default'}, 6);
	print "</tr>\n";

	print "<tr>\n";
	print &opt_input($text{'eadm_caf'}, "announce_file", $conf,
			 $text{'eadm_none'}, 35, &file_chooser_button("announce_file"));
	print "</tr>\n";

	print "<tr>\n";
	print &opt_time_input($text{'eadm_annp'}, "announce_period", $conf,
			      $text{'eadm_default'}, 4);
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
print "<input type=submit value=$text{'eadm_buttsave'}></form>\n";

&ui_print_footer("", $text{'eadm_return'});

