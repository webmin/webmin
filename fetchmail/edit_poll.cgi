#!/usr/local/bin/perl
# edit_poll.cgi
# Display one server polled by fetchmail

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

if ($in{'new'}) {
	&ui_print_header($uheader, $text{'poll_create'}, "");
	}
else {
	&ui_print_header($uheader, $text{'poll_edit'}, "");
	@conf = &parse_config_file($file);
	$poll = $conf[$in{'idx'}];
	}

print "<form action=save_poll.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=file value='$file'>\n";
print "<input type=hidden name=user value='$in{'user'}'>\n";

# Show server options
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'poll_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'poll_poll'}</b></td>\n";
printf "<td><input name=poll size=30 value='%s'></td>\n",
	$poll->{'poll'};

print "<td><b>$text{'poll_skip'}</b></td>\n";
printf "<td><input type=radio name=skip value=0 %s> %s\n",
	$poll->{'skip'} ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=skip value=1 %s> %s</td> </tr>\n",
	$poll->{'skip'} ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'poll_via'}</b></td>\n";
printf "<td colspan=3><input type=radio name=via_def value=1 %s> %s\n",
	$poll->{'via'} ? '' : 'checked', $text{'poll_via_def'};
printf "<input type=radio name=via_def value=0 %s>\n",
	$poll->{'via'} ? 'checked' : '';
printf "<input name=via size=30 value='%s'></td> </tr>\n",
	$poll->{'via'};

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

print "<tr> <td><b>$text{'poll_auth'}</b></td>\n";
print "<td><select name=auth>\n";
printf "<option value='' %s>%s</option>\n",
	$poll->{'auth'} ? '' : 'selected', $text{'default'};
foreach $p ('password', 'kerberos_v5', 'kerberos_v4', 'gssapi', 'cram-md5', 'otp', 'ntlm', 'ssh') {
        printf "<option value=%s %s>%s</option>\n",
                $p, lc($poll->{'auth'}) eq $p ? 'selected' : '', uc($p);
        $found++ if (lc($poll->{'auth'}) eq $p);
        }
printf "<option value=%s selected>%s</option>\n", $poll->{'auth'}, uc($poll->{'auth'})
        if (!$found && $poll->{'auth'});
print "</select></td> </tr>\n";

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

# Show user options
@users = @{$poll->{'users'}};
push(@users, undef) if ($in{'new'} || $in{'adduser'});
$i = 0;
foreach $u (@users) {
	print "<br><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'poll_uheader'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'poll_user'}</b></td>\n";
	printf "<td><input name=user_$i size=15 value='%s'></td>\n",
		$u->{'user'};

	print "<td><b>$text{'poll_pass'}</b></td>\n";
	print "<td>",&ui_password("pass_$i", $u->{'pass'}, 15),"</td> </tr>\n";

	print "<tr> <td><b>$text{'poll_is'}</b></td> <td colspan=3>\n";
	printf "<input name=is_$i size=60 value='%s'></td> </tr>\n",
		join(" ", @{$u->{'is'}}) || $remote_user;

	print "<tr> <td><b>$text{'poll_keep'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=keep_$i value=1 %s> %s\n",
		$u->{'keep'} eq '1' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=keep_$i value=0 %s> %s\n",
		$u->{'keep'} eq '0' ? 'checked' : '', $text{'no'};
	printf "<input type=radio name=keep_$i value='' %s> %s (%s)\n",
		$u->{'keep'} eq '' ? 'checked' : '', $text{'default'},
		$text{'poll_usually'};
	print "</td> </tr>\n";

	print "<td><b>$text{'poll_fetchall'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=fetchall_$i value=1 %s> %s\n",
		$u->{'fetchall'} eq '1' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=fetchall_$i value=0 %s> %s\n",
		$u->{'fetchall'} eq '0' ? 'checked' : '', $text{'no'};
	printf "<input type=radio name=fetchall_$i value='' %s> %s (%s)\n",
		$u->{'fetchall'} eq '' ? 'checked' : '', $text{'default'},
		$text{'poll_usually'};
	print "</td> </tr>\n";

	print "<td><b>$text{'poll_ssl'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=ssl_$i value=1 %s> %s\n",
		$u->{'ssl'} eq '1' ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=ssl_$i value=0 %s> %s\n",
		$u->{'ssl'} eq '0' ? 'checked' : '', $text{'no'};
	printf "<input type=radio name=ssl_$i value='' %s> %s (%s)\n",
		$u->{'ssl'} eq '' ? 'checked' : '', $text{'default'},
		$text{'poll_usually'};
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'poll_preconnect'}</b></td>\n";
	$u->{'preconnect'} =~ s/'/&#39;/g;
	printf "<td colspan=3><input name=preconnect_$i size=50 value='%s'></td> </tr>\n", $u->{'preconnect'};

	print "<tr> <td><b>$text{'poll_postconnect'}</b></td>\n";
	$u->{'postconnect'} =~ s/'/&#39;/g;
	printf "<td colspan=3><input name=postconnect_$i size=50 value='%s'></td></tr>\n", $u->{'postconnect'};

	print "</table></td></tr></table>\n";
	$i++;
	}

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	if (!$in{'adduser'}) {
		print "<td align=middle><input type=submit name=adduser ",
		      "value='$text{'poll_adduser'}'></td>\n";
		}
	print "<td align=middle><input type=submit name=check ",
	      "value='$text{'poll_check'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";

if (!$fetchmail_config && $config{'view_mode'}) {
	&ui_print_footer("edit_user.cgi?user=$in{'user'}", $text{'user_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

