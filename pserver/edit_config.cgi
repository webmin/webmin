#!/usr/local/bin/perl
# edit_config.cgi
# Display server configuration options

require './pserver-lib.pl';
$access{'config'} || &error($text{'config_ecannot'});
&ui_print_header(undef, $text{'config_title'}, "");
@conf = &get_cvs_config();

print "<form action=save_config.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'config_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$auth = &find("SystemAuth", \@conf);
print "<tr> <td><b>$text{'config_auth'}</b></td>\n";
printf "<td><input type=radio name=auth value=1 %s> %s\n",
	$auth->{'value'} eq 'no' ? "" : "checked", $text{'yes'};
printf "<input type=radio name=auth value=0 %s> %s</td> </tr>\n",
	$auth->{'value'} eq 'no' ? "checked" : "", $text{'no'};

$top = &find("TopLevelAdmin", \@conf);
print "<tr> <td><b>$text{'config_top'}</b></td>\n";
printf "<td><input type=radio name=top value=1 %s> %s\n",
	$top->{'value'} eq 'yes' ? "checked" : "", $text{'yes'};
printf "<input type=radio name=top value=0 %s> %s</td> </tr>\n",
	$top->{'value'} eq 'yes' ? "" : "checked", $text{'no'};

$hist = &find("LogHistory", \@conf);
$all++ if (!$hist || lc($hist->{'value'}) eq 'all');
map { $hist{lc($_)}++ } split(//, $hist->{'value'}) if (!$all);
print "<tr> <td valign=top><b>$text{'config_hist'}</b></td>\n";
printf "<td><input type=radio name=hist_def value=1 %s> %s\n",
	$all ? "checked" : "", $text{'config_hist_all'};
printf "<input type=radio name=hist_def value=0 %s> %s<br>\n",
	$all ? "" : "checked", $text{'config_hist_sel'};
print "<table width=100%>\n";
$i = 0;
foreach $h (@hist_chars) {
	print "<tr>\n" if ($i%2 == 0);
	printf "<td><input type=checkbox name=hist value=%s %s> %s</td>\n",
		$h, $hist{lc($h)} ? "checked" : "", $text{'config_hist_'.$h};
	print "</tr>\n" if ($i%2 == 1);
	$i++;
	}
print "</table></td></tr>\n";

$lock = &find("LockDir", \@conf);
print "<tr> <td><b>$text{'config_lock'}</b></td>\n";
printf "<td><input type=radio name=lock_def value=1 %s> %s\n",
	$lock ? "" : "checked", $text{'default'};
printf "<input type=radio name=lock_def value=0 %s>\n",
	$lock ? "checked" : "";
printf "<input name=lock size=30 value='%s'> %s</td> </tr>\n",
	$lock->{'value'}, &file_chooser_button("lock");

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

