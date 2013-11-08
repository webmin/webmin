#!/usr/local/bin/perl
# edit_global.cgi
# Edit options for all poll sections in a file

require './fetchmail-lib.pl';
&ReadParse();

if ($config{'config_file'}) {
	$file = $config{'config_file'};
	}
else {
	&can_edit_user($in{'user'}) || &error($text{'poll_ecannot'});
	@uinfo = getpwnam($in{'user'});
	$file = "$uinfo[7]/.fetchmailrc";
	$uheader = &text('poll_foruser', "<tt>$in{'user'}</tt>");
	}

&ui_print_header($uheader, $text{'global_title'}, "");

@conf = &parse_config_file($file);
foreach $c (@conf) {
	$poll = $c if ($c->{'defaults'});
	}

print "<form action=save_global.cgi>\n";
print "<input type=hidden name=file value='$file'>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";

# Show default server options
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'global_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'poll_proto'}</b></td>\n";
print "<td><select name=proto>\n";
printf "<option value='' %s>%s</option>\n",
	$poll->{'proto'} ? '' : 'selected', $text{'default'};
foreach $p ('pop3', 'pop2', 'imap', 'imap-k4', 'imap-gss', 'apop', 'kpop') {
	printf "<option value=%s %s>%s</option>\n",
		$p, lc($poll->{'proto'}) eq $p ? 'selected' : '', uc($p);
	$found++ if (lc($poll->{'proto'}) eq $p);
	}
printf "<option value=%s selected>%s</option>\n", $poll->{'proto'}, uc($poll->{'proto'})
	if (!$found && $poll->{'proto'});
print "</select></td>\n";

print "<td><b>$text{'poll_port'}</b></td>\n";
printf "<td><input type=radio name=port_def value=1 %s> %s\n",
	$poll->{'port'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=port_def value=0 %s> %s\n",
	$poll->{'port'} ? 'checked' : '';
printf "<input name=port size=8 value='%s'></td> </tr>\n",
	$poll->{'port'};

@interface = split(/\//, $poll->{'interface'});
print "<tr> <td valign=top><b>$text{'poll_interface'}</b></td><td colspan=3>\n";
printf "<input type=radio name=interface_def value=1 %s> %s<br>\n",
	@interface ? '' : 'checked', $text{'poll_interface_def'};
printf "<input type=radio name=interface_def value=0 %s> %s\n",
	@interface ? 'checked' : '', $text{'poll_interface_ifc'};
print "<input name=interface size=8 value='$interface[0]'> ",
      "$text{'poll_interface_ip'}\n";
print "<input name=interface_net size=15 value='$interface[1]'> /\n";
print "<input name=interface_mask size=15 value='$interface[2]'></td> </tr>\n";

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
print "</tr></table>\n";

if (!$fetchmail_config && $config{'view_mode'}) {
	&ui_print_footer("edit_user.cgi?user=$in{'user'}", $text{'user_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

