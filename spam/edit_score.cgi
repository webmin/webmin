#!/usr/local/bin/perl
# edit_score.cgi
# Display a form for editing spam scoring options

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("score");
&ui_print_header($header_subtext, $text{'score_title'}, "");
$conf = &get_config();

print "$text{'score_desc'}<p>\n";
&start_form("save_score.cgi", $text{'score_header'});

$hits_param = &version_atleast(3.0) ? "required_score" : "required_hits";
print "<tr> <td><b>$text{'score_hits'}</b></td> <td nowrap colspan=2>";
$hits = &find($hits_param, $conf);
&opt_field($hits_param, $hits, 5, "5");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_auto'}</b></td> <td nowrap colspan=2>";
$auto = &find("auto_whitelist_factor", $conf);
&opt_field("auto_whitelist_factor", $auto, 5, "0.5");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_bayes'}</b></td> <td nowrap colspan=2>";
$bayes = &find("use_bayes", $conf);
&yes_no_field("use_bayes", $bayes, 1);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_mx'}</b></td> <td nowrap colspan=2>";
$mx = &find("check_mx_attempts", $conf);
&opt_field("check_mx_attempts", $mx, 4, "2");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_mxdelay'}</b></td> <td nowrap colspan=2>";
$mxdelay = &find("check_mx_delay", $conf);
&opt_field("check_mx_delay", $mxdelay, 4, "2");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_rbl'}</b></td> <td nowrap colspan=2>";
$rbl = &find("skip_rbl_checks", $conf);
&yes_no_field("skip_rbl_checks", $rbl, 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_timeout'}</b></td> <td nowrap colspan=2>";
$timeout = &find("rbl_timeout", $conf);
&opt_field("rbl_timeout", $timeout, 5, "30");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'score_received'}</b></td> <td nowrap colspan=2>";
$received = &find("num_check_received", $conf);
&opt_field("num_check_received", $received, 5, 2);
print "</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

@langs = &find_value("ok_languages", $conf);
%langs = map { $_, 1 } split(/\s+/, join(" ", @langs));
$lmode = !@langs ? 2 : $langs{'all'} ? 1 : 0;
print "<tr> <td valign=top><b>$text{'score_langs'}</b></td> <td valign=top>\n";
printf "<input type=radio name=langs_def value=2 %s> %s (%s)<br>\n",
	$lmode == 2 ? 'checked' : '', $text{'default'}, $text{'score_langsall'};
printf "<input type=radio name=langs_def value=1 %s> %s<br>\n",
	$lmode == 1 ? 'checked' : '', $text{'score_langsall'};
printf "<input type=radio name=langs_def value=0 %s> %s<br>\n",
	$lmode == 0 ? 'checked' : '', $text{'score_langssel'};
print "</td> <td><select name=langs multiple size=5>\n";
open(LANGS, "$module_root_directory/langs");
while(<LANGS>) {
	if (/^(\S+)\s+(.*)/) {
		printf "<option value=%s %s>%s\n",
			$1, $langs{$1} ? "selected" : "", $2;
		}
	}
close(LANGS);
print "</select></td> </tr>\n";

@locales = &find_value("ok_locales", $conf);
%locales = map { $_, 1 } split(/\s+/, join(" ", @locales));
$lmode = !@locales ? 2 : $locales{'all'} ? 1 : 0;
print "<tr> <td valign=top><b>$text{'score_locales'}</b></td> <td valign=top>\n";
printf "<input type=radio name=locales_def value=2 %s> %s (%s)<br>\n",
	$lmode == 2 ? 'checked' : '', $text{'default'},$text{'score_localesall'};
printf "<input type=radio name=locales_def value=1 %s> %s<br>\n",
	$lmode == 1 ? 'checked' : '', $text{'score_localesall'};
printf "<input type=radio name=locales_def value=0 %s> %s<br>\n",
	$lmode == 0 ? 'checked' : '', $text{'score_localessel'};
print "</td> <td><select name=locales multiple size=5>\n";
open(LANGS, "$module_root_directory/locales");
while(<LANGS>) {
	if (/^(\S+)\s+(.*)/) {
		printf "<option value=%s %s>%s\n",
			$1, $locales{$1} ? "selected" : "", $2;
		}
	}
close(LANGS);
print "</select></td> </tr>\n";

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

