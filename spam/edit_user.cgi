#!/usr/local/bin/perl
# edit_user.cgi
# Display other misc user-level options

require './spam-lib.pl';
&can_use_check("user");
&ui_print_header(undef, $text{'user_title'}, "");
$conf = &get_config();

print "$text{'user_desc'}<p>\n";
&start_form("save_user.cgi", $text{'user_header'});

$dns = lc(&find_value("dns_available", $conf));
$dns = "test" if (!$dns && $config{'defaults'});
print "<tr> <td><b>$text{'user_dns'}</b></td> <td nowrap>\n";
printf "<input type=radio name=dns value=1 %s> %s\n",
	$dns eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=dns value=0 %s> %s\n",
	$dns eq 'no' ? "checked" : "", $text{'no'};
if (!$config{'defaults'}) {
	printf "<input type=radio name=dns value=-1 %s> %s (%s)\n",
		!$dns ? "checked" : "", $text{'default'}, $text{'user_dnstest'};
	}
printf "<input type=radio name=dns value=2 %s> %s\n",
	$dns =~ /^test/ ? "checked" : "", $text{'user_dnslist'};
printf "<input name=dnslist size=30 value='%s'></td> </tr>\n",
	$dns =~ /^test:\s*(.*)/ ? $1 : "";

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'user_razor'}</b></td> <td nowrap>\n";
$razor = &find("razor_timeout", $conf);
&opt_field("razor_timeout", $razor, 5, 10);
print "</td> </tr>\n";

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'user_dcc'}</b></td> <td>\n";
$dcc = &find("dcc_path", $conf);
&opt_field("dcc_path", $dcc, 40, $text{'user_inpath'}, 1);
print &file_chooser_button("dcc_path", 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_bodymax'}</b></td> <td nowrap>\n";
$bodymax = &find("dcc_body_max", $conf);
&opt_field("dcc_body_max", $bodymax, 6, 999999);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_timeout'}</b></td> <td nowrap>\n";
$timeout = &find("dcc_timeout", $conf);
&opt_field("dcc_timeout", $timeout, 5, 10);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_fuz1max'}</b></td> <td nowrap>\n";
$fuz1max = &find("dcc_fuz1_max", $conf);
&opt_field("dcc_fuz1_max", $fuz1max, 6, 999999);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_fuz2max'}</b></td> <td nowrap>\n";
$fuz2max = &find("dcc_fuz2_max", $conf);
&opt_field("dcc_fuz2_max", $fuz2max, 6, 999999);
print "</td> </tr>\n";

if (!&version_atleast(3)) {
	print "<tr> <td><b>$text{'user_dheader'}</b></td> <td nowrap>\n";
	$dheader = &find("dcc_add_header", $conf);
	&yes_no_field("dcc_add_header", $dheader, 0);
	print "</td> </tr>\n";
	}

print "<tr> <td colspan=2><hr></td> </tr>\n";

print "<tr> <td><b>$text{'user_pyzor'}</b></td> <td>\n";
$pyzor = &find("pyzor_path", $conf);
&opt_field("pyzor_path", $pyzor, 40, $text{'user_inpath'}, 1);
print &file_chooser_button("pyzor_path", 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_pbodymax'}</b></td> <td nowrap>\n";
$pbodymax = &find("pyzor_body_max", $conf);
&opt_field("pyzor_body_max", $pbodymax, 6, 999999);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_ptimeout'}</b></td> <td nowrap>\n";
$ptimeout = &find("pyzor_timeout", $conf);
&opt_field("pyzor_timeout", $ptimeout, 5, 10);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'user_pheader'}</b></td> <td nowrap>\n";
$pheader = &find("pyzor_add_header", $conf);
&yes_no_field("pyzor_add_header", $pheader, 0);
print "</td> </tr>\n";

&end_form(undef, $text{'save'});
&ui_print_footer("", $text{'index_return'});


