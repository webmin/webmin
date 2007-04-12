#!/usr/local/bin/perl
# edit_general.cgi
# Edit general jabber server options

require './jabber-lib.pl';
&ui_print_header(undef, $text{'general_title'}, "", "general");

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);

print "<form action=save_general.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'general_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$host = &find("host", $session);
$hostname = &find_by_tag("jabberd:cmdline", "flag", "h", $host);
print "<tr> <td><b>$text{'general_host'}</b></td>\n";
printf "<td colspan=3><input name=host size=40 value='%s'></td> </tr>\n",
	&value_in($hostname);

$elogger = &find_by_tag("log", "id", "elogger", $conf);
print "<tr> <td><b>$text{'general_elog'}</b></td>\n";
printf "<td><input name=elog size=25 value='%s'></td>\n",
	&find_value("file", $elogger);

print "<td><b>$text{'general_elogfmt'}</b></td>\n";
printf "<td><input name=elogfmt size=25 value='%s'></td> </tr>\n",
	&find_value("format", $elogger);

$rlogger = &find_by_tag("log", "id", "rlogger", $conf);
print "<tr> <td><b>$text{'general_rlog'}</b></td>\n";
printf "<td><input name=rlog size=25 value='%s'></td>\n",
	&find_value("file", $rlogger);

print "<td><b>$text{'general_rlogfmt'}</b></td>\n";
printf "<td><input name=rlogfmt size=25 value='%s'></td> </tr>\n",
	&find_value("format", $rlogger);

$pidfile = &find_value("pidfile", $conf);
print "<tr> <td><b>$text{'general_pidfile'}</b></td>\n";
printf "<td colspan=3><input name=pidfile size=40 value='%s'></td> </tr>\n",
	$pidfile;

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

