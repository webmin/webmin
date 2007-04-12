#!/usr/local/bin/perl
# edit_messages.cgi
# Display welcome and other messages

require './jabber-lib.pl';
&ui_print_header(undef, $text{'messages_title'}, "", "messages");

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);

print "<form action=save_messages.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'messages_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$welcome = &find("welcome", $jsm);
print "<tr> <td><b>$text{'messages_wsubject'}</b></td>\n";
printf "<td colspan=3><input name=wsubject size=50 value='%s'></td> </tr>\n",
	&find_value("subject", $welcome);
print "<tr> <td valign=top><b>$text{'messages_wbody'}</b></td>\n";
print "<td colspan=3><textarea name=wbody rows=4 cols=50 wrap=auto>",
	&find_value("body", $welcome),"</textarea></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

$register = &find("register", $jsm);
print "<tr> <td><b>$text{'messages_rinstr'}</b></td>\n";
printf "<td colspan=3><input name=rinstr size=50 value='%s'></td> </tr>\n",
	&find_value("instructions", $register);
print "<tr> <td><b>$text{'messages_rnotify'}</b></td>\n";
printf "<td><input type=radio name=rnotify value=1 %s> %s\n",
	$register->[1]->[0]->{'notify'} eq 'yes' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=rnotify value=0 %s> %s</td>\n",
	$register->[1]->[0]->{'notify'} eq 'yes' ? '' : 'checked', $text{'no'};
print "<td><b>$text{'messages_rfields'}</b></td> <td>\n";
foreach $f (@register_fields) {
	local $rf = &find($f, $register);
	printf "<input type=checkbox name=%s value=1 %s> %s\n",
		"rfield_$f", $rf ? "checked" : "", $f;
	}
print "</td></tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

$vcard = &find("vcard", $jsm);
@vc = @{$vcard->[1]}; shift(@vc);
print "<tr> <td valign=top><b>$text{'messages_vcard'}</b></td>\n";
print "<td colspan=3><textarea name=vcard rows=4 cols=50 wrap=auto>",
	&xml_string($vcard->[0], $vcard->[1]),"</textarea></td> </tr>\n";

$vcard2jud = &find("vcard2jud", $jsm);
print "<tr> <td><b>$text{'messages_vcard2jud'}</b></td>\n";
printf "<td><input type=radio name=vcard2jud value=1 %s> %s\n",
	$vcard2jud ? "checked" : "", $text{'yes'};
printf "<input type=radio name=vcard2jud value=0 %s> %s</td> </tr>\n",
	$vcard2jud ? "" : "checked", $text{'no'};

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

