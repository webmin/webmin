#!/usr/local/bin/perl
# edit_karma.cgi
# Edit karma traffic limitation options

require './jabber-lib.pl';
&ui_print_header(undef, $text{'karma_title'}, "", "karma");

$conf = &get_jabber_config();
$io = &find("io", $conf);
$karma = &find("karma", $io);

print "<form action=save_karma.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'karma_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$rate = &find("rate", $io);
print "<tr> <td><b>$text{'karma_rate'}</b></td>\n";
printf "<td><input type=radio name=rate_def value=1 %s> %s\n",
	$rate ? "" : "checked", $text{'karma_rate_def'};
printf "<input type=radio name=rate_def value=0 %s>\n",
	$rate ? "checked" : "";
print &text('karma_rate_sel',
	    "<input name=points size=5 value='$rate->[1]->[0]->{'points'}'>",
	    "<input name=time size=5 value='$rate->[1]->[0]->{'time'}'>"),
	   "</td> </tr>\n";

$mode = $karma ? 3 : -1;
for($i=0; $i<@karma_presets; $i++) {
	local $kp = $karma_presets[$i];
	local $different = 0;
	foreach $k (keys %$kp) {
		local $v = &find_value($k, $karma);
		if ($v != $kp->{$k}) {
			$different++;
			last;
			}
		}
	if (!$different) {
		$mode = $i;
		last;
		}
	}

print "<tr> <td valign=top><b>$text{'karma_mode'}</b></td>\n";
print "<td><select name=mode>\n";
printf "<option value=-1 %s>%s</option>\n",
	$mode == -1 ? "selected" : "", $text{'karma_none'};
printf "<option value=0 %s>%s</option>\n",
	$mode == 0 ? "selected" : "", $text{'karma_low'};
printf "<option value=1 %s>%s</option>\n",
	$mode == 1 ? "selected" : "", $text{'karma_medium'};
printf "<option value=2 %s>%s</option>\n",
	$mode == 2 ? "selected" : "", $text{'karma_high'};
printf "<option value=3 %s>%s</option>\n",
	$mode == 3 ? "selected" : "", $text{'karma_sel'};
print "</select><br><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'karma_heartbeat'}</b></td>\n";
printf "<td><input name=heartbeat size=6 value='%s'></td>\n",
	&find_value("heartbeat", $karma);

print "<td><b>$text{'karma_init'}</b></td>\n";
printf "<td><input name=init size=6 value='%s'></td> </tr>\n",
	&find_value("init", $karma);

print "<tr> <td><b>$text{'karma_max'}</b></td>\n";
printf "<td><input name=max size=6 value='%s'></td>\n",
	&find_value("max", $karma);

print "<td><b>$text{'karma_dec'}</b></td>\n";
printf "<td><input name=dec size=6 value='%s'></td> </tr>\n",
	&find_value("dec", $karma);

$p = &find_value("penalty", $karma);
print "<tr> <td><b>$text{'karma_penalty'}</b></td>\n";
printf "<td><input name=penalty size=6 value='%s'></td>\n",
	defined($p) ? $p * -1 : undef;

print "<td><b>$text{'karma_restore'}</b></td>\n";
printf "<td><input name=restore size=6 value='%s'></td> </tr>\n",
	&find_value("restore", $karma);

print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

