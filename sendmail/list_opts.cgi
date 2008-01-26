#!/usr/local/bin/perl
# list_opts.cgi
# A form for editing options set with the 'O foo=bar' directive,
# and other things.

require './sendmail-lib.pl';
$access{'opts'} || &error($text{'opts_ecannot'});
&ui_print_header(undef, $text{'opts_title'}, "");

$conf = &get_sendmailcf();
$ver = &check_sendmail_version($conf);
$default = $text{'opts_default'};
print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'opts_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

($dsstr, $ds) = &find_type2("D", "S", $conf);
print "<tr> <td>",&hlink("<b>$text{'opts_ds'}</b>","opt_DS"),
      "</td> <td colspan=3>\n";
printf "<input type=radio name=DS_def value=1 %s> $text{'opts_direct'}\n",
	$ds ? "" : "checked";
printf "<input type=radio name=DS_def value=0 %s>\n",
	$ds ? "checked" : "";
print "<input name=DS size=25 value=\"$ds\"></td> </tr>\n";

($drstr, $dr) = &find_type2("D", "R", $conf);
print "<tr> <td>",&hlink("<b>$text{'opts_dr'}</b>",
			 "opt_DR"),"</td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=DR_def value=1 %s> $text{'opts_local'}\n",
	$dr ? "" : "checked";
printf "<input type=radio name=DR_def value=0 %s>\n",
	$dr ? "checked" : "";
print "<input name=DR size=25 value=\"$dr\"></td> </tr>\n";

($dhstr, $dh) = &find_type2("D", "H", $conf);
print "<tr> <td>",&hlink("<b>$text{'opts_dh'}</b>",
			 "opt_DH"),"</td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=DH_def value=1 %s> $text{'opts_local'}\n",
	$dh ? "" : "checked";
printf "<input type=radio name=DH_def value=0 %s>\n",
	$dh ? "checked" : "";
print "<input name=DH size=25 value=\"$dh\"></td> </tr>\n";

($dmstr, $dm) = &find_option("DeliveryMode", $conf);
print "<tr> <td>",&hlink("<b>$text{'opts_dmode'}</b>","opt_dmode"),
      "</td> <td colspan=3>\n";
printf "<input type=radio name=DeliveryMode value='' %s> $text{'default'}\n",
	$dm ? '' : 'checked';
foreach $dmo ('background', 'queue-only', 'interactive', 'deferred') {
	local $dmoc = substr($dmo, 0, 1);
	printf "<input type=radio name=DeliveryMode value=%s %s> %s\n",
		$dmo, $dm =~ /^$dmoc/ ? 'checked' : '', $text{"opts_$dmo"};
	}
print "</td> </tr>\n";

($qsostr, $qso) = &find_option("QueueSortOrder", $conf);
print "<tr> <td>",&hlink("<b>$text{'opts_qso'}</b>","opt_qso"),
      "</td> <td colspan=3>\n";
printf "<input type=radio name=QueueSortOrder value='' %s> $text{'default'}\n",
	$qso ? '' : 'checked';
foreach $dmo ('priority', 'host', 'time') {
	local $dmoc = substr($dmo, 0, 1);
	printf "<input type=radio name=QueueSortOrder value=%s %s> %s\n",
		$dmo, $qso =~ /^$dmoc/ ? 'checked' : '', $text{"opts_$dmo"};
	}
print "</td> </tr>\n";

print "<tr>\n";
&option_input($text{'opts_queuela'}, "QueueLA", $conf, $default, 6);
&option_input($text{'opts_refusela'}, "RefuseLA", $conf, $default,6);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_maxch'}, "MaxDaemonChildren",
	      $conf, $default, 6);
&option_input($text{'opts_throttle'}, "ConnectionRateThrottle",
	      $conf, $default, 6);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_minqueueage'}, "MinQueueAge",
	      $conf, $default, 6);
&option_input($text{'opts_runsize'}, "MaxQueueRunSize", $conf, $default, 8);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_queuereturn'}, "Timeout.queuereturn",
	      $conf, $default, 6);
&option_input($text{'opts_queuewarn'}, "Timeout.queuewarn",
	      $conf, $default, 6);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_queue'}, "QueueDirectory", $conf, $default, 35);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_postmaster'}, "PostMasterCopy",
	      $conf, "Postmaster", 35);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_forward'}, "ForwardPath", $conf, $default, 35);
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_minfree'}, "MinFreeBlocks",
	      $conf, $default, 8, $text{'opts_blocks'});
&option_input($text{'opts_maxmessage'}, "MaxMessageSize",
	      $conf, $default, 10, $text{'opts_bytes'});
print "</tr>\n";

print "<tr>\n";
&option_input($text{'opts_loglevel'}, "LogLevel", $conf, $default, 4);
($vstr, $v) = &find_option("SendMimeErrors", $conf);
print "<td>",&hlink("<b>$text{'opts_mimebounce'}</b>","opt_SendMimeErrors"),
      "</td> <td>\n";
printf "<input type=radio name=SendMimeErrors value=True %s> $text{'yes'}\n",
	$v eq "True" ? "checked" : "";
printf "<input type=radio name=SendMimeErrors value=False %s> $text{'no'}\n",
	$v eq "True" ? "" : "checked";
print "</td> </tr>\n";

print "<tr>\n";
($gstr, $g) = &find_option("MatchGECOS", $conf);
print "<td>",&hlink("<b>$text{'opts_gecos'}</b>","opt_MatchGECOS"),
      "</td> <td>\n";
printf "<input type=radio name=MatchGECOS value=True %s> $text{'yes'}\n",
	$g eq "True" ? "checked" : "";
printf "<input type=radio name=MatchGECOS value=False %s> $text{'no'}</td>\n",
	$g eq "True" ? "" : "checked";
&option_input($text{'opts_hops'}, "MaxHopCount", $conf, $default, 4);
print "</tr>\n";

if ($ver >= 10) {
	print "<tr>\n";
	&option_input($text{'opts_maxrcpt'}, "MaxRecipientsPerMessage", $conf, $default, 4);
	&option_input($text{'opts_maxbad'}, "BadRcptThrottle", $conf, $default, 4);
	print "</tr>\n";
	}

print "<tr>\n";
($bstr, $b) = &find_option("DontBlameSendmail", $conf);
print "<td valign=top>",&hlink("<b>$text{'opts_blame'}</b>",
      "opt_DontBlameSendmail"),"</td> <td colspan=3>\n";
printf "<input type=radio name=DontBlameSendmail_def value=1 %s> %s\n",
	$b ? '' : 'checked', $text{'default'};
printf "<input type=radio name=DontBlameSendmail_def value=0 %s> %s<br>\n",
	$b ? 'checked' : '', $text{'opts_selected'};
print &ui_select("DontBlameSendmail",
	 [ split(/[\s,]+/, $b) ],
	 [ map { [ $_->[0],
		   "$_->[0] (".(length($_->[1]) > 40 ? substr($_->[1], 0, 40)."..." : $_->[1]).")" ] } &list_dontblames() ],
	 5, 1, 1);
print "</td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

# option_input(desc, name, &config, default, size, units)
sub option_input
{
local ($vstr, $v) = &find_option($_[1], $_[2]);
printf "<td>".&hlink("<b>$_[0]</b>","opt_".$_[1])."</td> <td %s nowrap>\n",
	$_[4] > 20 ? "colspan=3" : "";
print &ui_opt_textbox($_[1], $v, $_[4], $_[3])." $_[5]</td>\n";
}

# options_input(desc, name, &config, default, size, units)
sub options_input
{
local @vals = &find_options($_[1], $_[2]);
printf "<td valign=top>".&hlink("<b>$_[0]</b>","opt_".$_[1]).
       "</td> <td %s nowrap>\n",
	$_[4] > 20 ? "colspan=3" : "";
print &ui_radio("$_[1]_def", @vals ? 0 : 1,
		[ [ 1, $_[3] ], [ 0, $text{'opts_below'} ] ]),"<br>\n";
print &ui_textarea($_[1], join("\n", map { $_->[1] } @vals), 3, $_[4])."</td>\n";
}

