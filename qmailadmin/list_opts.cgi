#!/usr/local/bin/perl
# list_opts.cgi
# Display global QMail options

require './qmail-lib.pl';
&ui_print_header(undef, $text{'opts_title'}, "");

print "<form action=save_opts.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'opts_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'opts_me'}</b></td> <td colspan=3>\n";
printf "<input name=me size=35 value='%s'></td> </tr>\n",
	&get_control_file("me");

$helo = &get_control_file("helohost");
print "<tr> <td><b>$text{'opts_helo'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=helo_def value=1 %s> %s\n",
	$helo ? "" : "checked", $text{'default'};
printf "<input type=radio name=helo_def value=0 %s>\n",
	$helo ? "checked" : "";
printf "<input name=helo size=35 value='%s'></td> </tr>\n", $helo;

$toconnect = &get_control_file("timeoutconnect");
print "<tr> <td><b>$text{'opts_toconnect'}</b></td> <td nowrap>\n";
printf "<input type=radio name=toconnect_def value=1 %s> %s\n",
	$toconnect ? "" : "checked", $text{'default'};
printf "<input type=radio name=toconnect_def value=0 %s>\n",
	$toconnect ? "checked" : "";
printf "<input name=toconnect size=6 value='%s'> %s</td>\n",
	$toconnect, $text{'opts_secs'};

$toremote = &get_control_file("timeoutremote");
print "<td><b>$text{'opts_toremote'}</b></td> <td nowrap>\n";
printf "<input type=radio name=toremote_def value=1 %s> %s\n",
	$toremote ? "" : "checked", $text{'default'};
printf "<input type=radio name=toremote_def value=0 %s>\n",
	$toremote ? "checked" : "";
printf "<input name=toremote size=6 value='%s'> %s</td> </tr>\n",
	$toremote, $text{'opts_secs'};

$bytes = &get_control_file("databytes");
print "<tr> <td><b>$text{'opts_bytes'}</b></td> <td nowrap>\n";
printf "<input type=radio name=bytes_def value=1 %s> %s\n",
	$bytes ? "" : "checked", $text{'opts_unlimited'};
printf "<input type=radio name=bytes_def value=0 %s>\n",
	$bytes ? "checked" : "";
printf "<input name=bytes size=10 value='%s'> bytes</td>\n", $bytes;

$timeout = &get_control_file("timeoutsmtpd");
print "<td><b>$text{'opts_timeout'}</b></td> <td nowrap>\n";
printf "<input type=radio name=timeout_def value=1 %s> %s\n",
	$timeout ? "" : "checked", $text{'default'};
printf "<input type=radio name=timeout_def value=0 %s>\n",
	$timeout ? "checked" : "";
printf "<input name=timeout size=6 value='%s'> %s</td> </tr>\n",
	$timeout, $text{'opts_secs'};

$localip = &get_control_file("localiphost");
print "<tr> <td><b>$text{'opts_localip'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=localip_def value=1 %s> %s\n",
	$localip ? "" : "checked", $text{'default'};
printf "<input type=radio name=localip_def value=0 %s>\n",
	$localip ? "checked" : "";
printf "<input name=localip size=35 value='%s'></td> </tr>\n", $localip;

$greet = &get_control_file("smtpgreeting");
print "<tr> <td><b>$text{'opts_greet'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=greet_def value=1 %s> %s\n",
	$greet ? "" : "checked", $text{'default'};
printf "<input type=radio name=greet_def value=0 %s>\n",
	$greet ? "checked" : "";
printf "<input name=greet size=35 value='%s'></td> </tr>\n", $greet;

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";
&ui_print_footer("", $text{'index_return'});

