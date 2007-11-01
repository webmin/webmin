#!/usr/local/bin/perl
# edit_ui.cgi
# Edit user interface options

require './usermin-lib.pl';
$access{'ui'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'ui_title'}, "");

&get_usermin_config(\%uconfig);
print $text{'ui_desc'},"<p>\n";
print "<form action=change_ui.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'ui_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

for($i=0; $i<@webmin::cs_names; $i++) {
	$cd = $webmin::cs_codes[$i];
	print "<tr> <td><b>$webmin::cs_names[$i]</b></td>\n";
	printf "<td><input type=radio name=${cd}_def value=1 %s> %s\n",
		defined($uconfig{$cd}) ? "" : "checked",
		$webmin::text{'ui_default'};
	printf "&nbsp;&nbsp;<input type=radio name=${cd}_def value=0 %s> %s\n",
		defined($gconfig{$cd}) ? "checked" : "",
		$webmin::text{'ui_rgb'};
	print "<input name=${cd}_rgb size=8 value='$uconfig{$cd}'>\n";
	print "</td> </tr>\n";
	}

print "<tr> <td><b>$text{'ui_texttitles'}</b></td>\n";
printf "<td><input type=radio name=texttitles value=1 %s> %s\n",
	$uconfig{'texttitles'} ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=texttitles value=0 %s> %s</td> </tr>\n",
	$uconfig{'texttitles'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'ui_sysinfo'}</b></td>\n";
print "<td><select name=sysinfo>\n";
foreach $m (0, 1, 4, 2, 3) {
        printf "<option value=%s %s> %s\n",
                $m, $uconfig{'sysinfo'} == $m ? 'selected' : '',
                $webmin::text{'ui_sysinfo'.$m};
        }
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'ui_nohost'}</b></td> <td>\n";
printf "<input name=nohostname type=radio value=0 %s> %s\n",
	$uconfig{'nohostname'} ? '' : 'checked', $text{'yes'};
printf "<input name=nohostname type=radio value=1 %s> %s</td> </tr>\n",
	$uconfig{'nohostname'} ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'ui_hostnamemode'}</b></td>\n";
print "<td><select name=hostnamemode>\n";
foreach $m (0 .. 3) {
	printf "<option value=%s %s>%s\n",
		$m, $uconfig{'hostnamemode'} == $m ? "selected" : "",
		$webmin::text{'ui_hnm'.$m};
	}
print "</select>\n";
printf "<input name=hostnamedisplay size=20 value='%s'>\n",
	$uconfig{'hostnamedisplay'};
print "</td> </tr>\n";

print "<tr> <td><b>$webmin::text{'ui_showlogin'}</b></td> <td>\n";
printf "<input name=showlogin type=radio value=1 %s> %s\n",
        $uconfig{'showlogin'} ? 'checked' : '', $text{'yes'};
printf "<input name=showlogin type=radio value=0 %s> %s</td> </tr>\n",
        $uconfig{'showlogin'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$webmin::text{'startpage_gotoone'}</b></td> <td>\n";
printf "<input name=gotoone type=radio value=1 %s> %s\n",
	$uconfig{'gotoone'} ? 'checked' : '', $text{'yes'};
printf "<input name=gotoone type=radio value=0 %s> %s</td> </tr>\n",
	$uconfig{'gotoone'} ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$webmin::text{'startpage_gotomodule'}</b></td>\n";
print "<td><select name=gotomodule>\n";
printf "<option value='' %s>%s\n",
	$uconfig{'gotomodule'} ? "" : "selected",
	$webmin::text{'startpage_gotonone'};
foreach $m (&list_modules()) {
	printf "<option value=%s %s>%s\n",
		$m->{'dir'}, $uconfig{'gotomodule'} eq $m->{'dir'} ?
				'selected' : '', $m->{'desc'};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'ui_feedbackmode'}</b></td>\n";
printf "<td><input type=radio name=feedback_def value=1 %s> %s\n",
	$uconfig{'feedback'} ? "" : "checked", $text{'no'};
printf "<input type=radio name=feedback_def value=0 %s> %s\n",
	$uconfig{'feedback'} ? "checked" : "", $text{'ui_feedbackyes'};
printf "<input name=feedback size=30 value='%s'></td> </tr>\n",
	$uconfig{'feedback'};

print "<tr> <td><b>$text{'ui_feedbackmail'}</b></td>\n";
printf "<td nowrap><input type=radio name=feedbackmail_def value=1 %s> %s\n",
	$uconfig{'feedbackmail'} ? "" : "checked",
	$text{'ui_feedbackmail1'};
printf "<input type=radio name=feedbackmail_def value=0 %s> %s\n",
	$uconfig{'feedbackmail'} ? "checked" : "",
	$text{'ui_feedbackmail0'};
printf "<input name=feedbackmail size=30 value='%s'></td> </tr>\n",
	$uconfig{'feedbackmail'};

print "<tr> <td><b>$text{'ui_feedbackhost'}</b></td>\n";
printf "<td><input type=radio name=feedbackhost_def value=1 %s> %s\n",
	$uconfig{'feedbackhost'} ? "" : "checked",
	$text{'ui_feedbackthis'};
printf "<input type=radio name=feedbackhost_def value=0 %s>\n",
	$uconfig{'feedbackhost'} ? "checked" : "";
printf "<input name=feedbackhost size=30 value='%s'></td> </tr>\n",
	$uconfig{'feedbackhost'};

print "<tr> <td><b>$text{'ui_tabs'}</b></td> <td>\n";
printf "<input name=notabs type=radio value=0 %s> %s\n",
	$uconfig{'notabs'} ? '' : 'checked', $text{'yes'};
printf "<input name=notabs type=radio value=1 %s> %s</td> </tr>\n",
	$uconfig{'notabs'} ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$webmin::text{'ui_dateformat'}</b></td> <td>\n";
print &ui_select("dateformat", $uconfig{'dateformat'} || "dd/mon/yyyy",
		   [ map { [ $_, $webmin::text{'ui_dateformat_'.$_} ] }
			 @webmin::webmin_date_formats ]);
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

