#!/usr/local/bin/perl
# edit_access.cgi
# Display access control SSHd options

require './sshd-lib.pl';
&ui_print_header(undef, $text{'access_title'}, "", "access");
$conf = &get_sshd_config();

print "<form action=save_access.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'access_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($version{'type'} eq 'ssh') {
	&scmd(1);
	@allowh = &find_value("AllowHosts", $conf);
	print "<td><b>$text{'access_allowh'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=allowh_def value=1 %s> %s\n",
		@allowh ? "" : "checked", $text{'access_all'};
	printf "<input type=radio name=allowh_def value=0 %s>\n",
		@allowh ? "checked" : "";
	printf "<input name=allowh size=50 value='%s'></td>\n",
		join(" ", @allowh);
	&ecmd();

	&scmd(1);
	@denyh = &find_value("DenyHosts", $conf);
	print "<td><b>$text{'access_denyh'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=denyh_def value=1 %s> %s\n",
		@denyh ? "" : "checked", $text{'access_none'};
	printf "<input type=radio name=denyh_def value=0 %s>\n",
		@denyh ? "checked" : "";
	printf "<input name=denyh size=50 value='%s'></td>\n",
		join(" ", @denyh);
	&ecmd();

	&scmd(1);
	print "<td colspan=4><hr></td>\n";
	&ecmd();
	}

$commas = $version{'type'} eq 'ssh' && $version{'number'} >= 3.2;

&scmd(1);
@allowu = &find_value("AllowUsers", $conf);
$allowu = $commas ? join(" ", split(/,/, $allowu[0]))
		  : join(" ", @allowu);
print "<td><b>$text{'access_allowu'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=allowu_def value=1 %s> %s\n",
	$allowu ? "" : "checked", $text{'access_all'};
printf "<input type=radio name=allowu_def value=0 %s>\n",
	$allowu ? "checked" : "";
printf "<input name=allowu size=50 value='%s'> %s</td>\n",
	$allowu, &user_chooser_button("allowu", 1);
&ecmd();

&scmd(1);
@allowg = &find_value("AllowGroups", $conf);
$allowg = $commas ? join(" ", split(/,/, $allowg[0]))
		  : join(" ", @allowg);
print "<td><b>$text{'access_allowg'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=allowg_def value=1 %s> %s\n",
	$allowg ? "" : "checked", $text{'access_all'};
printf "<input type=radio name=allowg_def value=0 %s>\n",
	$allowg ? "checked" : "";
printf "<input name=allowg size=50 value='%s'> %s</td>\n",
	$allowg, &group_chooser_button("allowg", 1);
&ecmd();

&scmd(1);
@denyu = &find_value("DenyUsers", $conf);
$denyu = $commas ? join(" ", split(/,/, $denyu[0]))
		 : join(" ", @denyu);
print "<td><b>$text{'access_denyu'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=denyu_def value=1 %s> %s\n",
	$denyu ? "" : "checked", $text{'access_none'};
printf "<input type=radio name=denyu_def value=0 %s>\n",
	$denyu ? "checked" : "";
printf "<input name=denyu size=50 value='%s'> %s</td>\n",
	$denyu, &user_chooser_button("denyu", 1);
&ecmd();

&scmd(1);
@denyg = &find_value("DenyGroups", $conf);
$denyg = $commas ? join(" ", split(/,/, $denyg[0]))
		 : join(" ", @denyg);
print "<td><b>$text{'access_denyg'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=denyg_def value=1 %s> %s\n",
	$denyg ? "" : "checked", $text{'access_none'};
printf "<input type=radio name=denyg_def value=0 %s>\n",
	$denyg ? "checked" : "";
printf "<input name=denyg size=50 value='%s'> %s</td>\n",
	$denyg, &group_chooser_button("denyg", 1);
&ecmd();

if ($version{'type'} eq 'ssh' && $version{'number'} < 2) {
	&scmd(1);
	print "<td colspan=4><hr></td>\n";
	&ecmd();

	&scmd();
	$silent = &find_value("SilentDeny", $conf);
	print "<td><b>$text{'access_silent'}</b></td> <td>\n";
	printf "<input type=radio name=silent value=1 %s> %s\n",
		lc($silent) eq 'yes' ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=silent value=0 %s> %s</td>\n",
		lc($silent) eq 'yes' ? "" : "checked", $text{'no'};
	&ecmd();
	}

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

