#!/usr/local/bin/perl
# edit_options.cgi
# Display options for the entire voicemail server

require './vgetty-lib.pl';
&ui_print_header(undef, $text{'options_title'}, "");
@conf = &get_config();

print "<form action=save_options.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'options_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$rings = &find_value("rings", \@conf);
if ($rings =~ /^\//) {
	open(TF, $rings);
	chop($rc = <TF>);
	close(TF);
	}
else { $rc = $rings; }
print "<tr> <td><b>$text{'options_rings'}</b></td>\n";
print "<td nowrap><input name=rings size=5 value='$rc'></td>\n";
printf "<td colspan=2><input type=checkbox name=rings_port value=1 %s> %s\n",
	$rings =~ /^\// ? "checked" : "", $text{'options_perport'};
print "</td> </tr>\n";

$ans = &find_value("answer_mode", \@conf);
if ($ans =~ /^\//) {
	open(TF, $ans);
	chop($rc = <TF>);
	close(TF);
	}
else { $rc = $ans; }
print "<tr> <td><b>$text{'options_ans'}</b></td>\n";
print "<td nowrap>",&answer_mode_input($rc, "ans"),"</td>\n";
printf "<td colspan=2><input type=checkbox name=ans_port value=1 %s> %s\n",
	$ans =~ /^\// ? "checked" : "", $text{'options_perport'};
print "</td> </tr>\n";

print "<tr> <td><b>$text{'options_maxlen'}</b></td>\n";
printf "<td><input name=maxlen size=8 value='%s'> %s</td>\n",
	&find_value("rec_max_len", \@conf), $text{'options_secs'};

print "<td><b>$text{'options_minlen'}</b></td>\n";
printf "<td><input name=minlen size=8 value='%s'> %s</td> </tr>\n",
	&find_value("rec_min_len", \@conf), $text{'options_secs'};

$silence = &find_value("rec_remove_silence", \@conf);
print "<tr> <td><b>$text{'options_silence'}</b></td>\n";
printf "<td nowrap><input type=radio name=silence value=1 %s> %s\n",
	$silence =~ /true/i ? "checked" : "", $text{'yes'};
printf "<input type=radio name=silence value=0 %s> %s</td>\n",
	$silence =~ /true/i ? "" : "checked", $text{'no'};

print "<td><b>$text{'options_thresh'}</b></td>\n";
printf "<td><input name=thresh size=3 value='%s'> %%</td> </tr>\n",
	&find_value("rec_silence_threshold", \@conf);

$rgain = &find_value("receive_gain", \@conf);
print "<tr> <td><b>$text{'options_rgain'}</b></td>\n";
printf "<td nowrap><input type=radio name=rgain_def value=1 %s> %s\n",
	$rgain == -1 ? "checked" : "", $text{'default'};
printf "<input type=radio name=rgain_def value=0 %s>\n",
	$rgain == -1 ? "" : "checked";
printf "<input name=rgain size=4 value='%s'> %%</td>\n",
	$rgain == -1 ? "" : $rgain;

$tgain = &find_value("transmit_gain", \@conf);
print "<td><b>$text{'options_tgain'}</b></td>\n";
printf "<td nowrap><input type=radio name=tgain_def value=1 %s> %s\n",
	$tgain == -1 ? "checked" : "", $text{'default'};
printf "<input type=radio name=tgain_def value=0 %s>\n",
	$tgain == -1 ? "" : "checked";
printf "<input name=tgain size=4 value='%s'> %%</td> </tr>\n",
	$tgain == -1 ? "" : $tgain;

$keep = &find_value("rec_always_keep", \@conf);
print "<tr> <td><b>$text{'options_keep'}</b></td>\n";
printf "<td nowrap><input type=radio name=keep value=1 %s> %s\n",
	$keep =~ /true/i ? "checked" : "", $text{'yes'};
printf "<input type=radio name=keep value=0 %s> %s</td>\n",
	$keep =~ /true/i ? "" : "checked", $text{'no'};

$light = &find_value("do_message_light", \@conf);
print "<td><b>$text{'options_light'}</b></td>\n";
printf "<td nowrap><input type=radio name=light value=1 %s> %s\n",
	$light =~ /true/i ? "checked" : "", $text{'yes'};
printf "<input type=radio name=light value=0 %s> %s</td> </tr>\n",
	$light =~ /true/i ? "" : "checked", $text{'no'};

print "<tr> <td><b>$text{'options_owner'}</b></td>\n";
printf "<td><input name=owner size=8 value='%s'> %s</td>\n",
	&find_value("phone_owner", \@conf), &user_chooser_button("owner");

print "<td><b>$text{'options_group'}</b></td>\n";
printf "<td><input name=group size=8 value='%s'> %s</td> </tr>\n",
	&find_value("phone_group", \@conf), &user_chooser_button("group");

print "<tr> <td><b>$text{'options_mode'}</b></td>\n";
printf "<td><input name=mode size=4 value='%s'></td>\n",
	&find_value("phone_mode", \@conf);

$prog = &find_value("message_program", \@conf);
$mode = !$prog ? 0 : $prog eq "$module_config_directory/email.pl" ? 1 : 2;
print "<tr> <td valign=top><b>$text{'options_prog'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=prog_mode value=0 %s> %s<br>\n",
	$mode == 0 ? "checked" : "", $text{'options_prog0'};
printf "<input type=radio name=prog_mode value=1 %s> %s\n",
	$mode == 1 ? "checked" : "", $text{'options_prog1'};
printf "<input name=email size=30 value='%s'><br>\n",
	$mode == 1 ? $config{'email_to'} : "";
printf "<input type=radio name=prog_mode value=2 %s> %s\n",
	$mode == 2 ? "checked" : "", $text{'options_prog2'};
printf "<input name=prog size=30 value='%s'></td> </tr>\n",
	$mode == 2 ? $prog : "";

print "</tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

