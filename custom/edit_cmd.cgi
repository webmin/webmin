#!/usr/local/bin/perl
# edit_cmd.cgi
# Display a custom command and its parameters

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'edit_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create");
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit");
	@cmds = &list_commands();
	$cmd = $cmds[$in{'idx'}];
	}

print "<form action=save_cmd.cgi method=post>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if (!$in{'new'}) {
	print "<tr> <td valign=top><b>",&hlink($text{'edit_id'}, "id"),
	      "</b></td>\n";
	print "<td><tt>$cmd->{'id'}</tt></td> </tr>\n";
	}

print "<tr> <td valign=top><b>",&hlink($text{'edit_desc'}, "desc"),
      "</b></td>\n";
print "<td colspan=3><input name=desc size=50 value='",
	&html_escape($cmd->{'desc'}),"'><br>\n";
print "<textarea name=html rows=2 cols=50>",$cmd->{'html'},
      "</textarea></td> </tr>\n";

if ($cmd->{'cmd'} =~ s/^\s*cd\s+(\S+)\s*;\s*//) {
	$dir = $1;
	}
print "<tr> <td><b>",&hlink($text{'edit_cmd'},"command"),"</b></td>\n";
print "<td colspan=3><input name=cmd size=50 value=\"".
	&html_escape($cmd->{'cmd'})."\"></td> </tr>\n";

print "<tr> <td><b>",&hlink($text{'edit_dir'},"dir"),"</b></td>\n";
$dir =~ s/"/&quot;/g;
printf "<td colspan=3><input type=radio name=dir_def value=1 %s> %s\n",
	$dir ? "" : "checked", $text{'default'};
printf "<input type=radio name=dir_def value=0 %s>\n",
	$dir ? "checked" : "";
printf "<input name=dir size=40 value=\"%s\"> %s</td> </tr>\n",
	$dir, &file_chooser_button("dir", 1);

if (&supports_users()) {
	print "<tr> <td><b>",&hlink($text{'edit_user'},"user"),"</b></td>\n";
	print "<td colspan=3>\n";
	printf "<input type=radio name=user_def value=1 %s> %s\n",
		$cmd->{'user'} eq '*' && !$in{'new'} ? "checked" : "",
		$text{'edit_user_def'};
	printf "<input type=radio name=user_def value=0 %s>\n",
		$cmd->{'user'} eq '*' && !$in{'new'} ? "" : "checked";
	printf "<input name=user size=8 value='%s'> %s\n",
		$cmd->{'user'} eq '*' ? '' : $cmd->{'user'},
		&user_chooser_button("user", 0);
	printf "<input type=checkbox name=su value=1 %s> %s</td> </tr>\n",
		$cmd->{'su'} ? 'checked' : '', $text{'edit_su'};
	}

print "<tr> <td><b>",&hlink($text{'edit_raw'},"raw"),"</b></td>\n";
printf "<td><input type=radio name=raw value=1 %s> %s\n",
	$cmd->{'raw'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=raw value=0 %s> %s</td>\n",
	$cmd->{'raw'} ? "" : "checked", $text{'no'};

print "<td><b>",&hlink($text{'edit_order'},"order"),"</b></td>\n";
printf "<td><input type=radio name=order_def value=1 %s> %s\n",
	$cmd->{'order'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=order_def value=0 %s>\n",
	$cmd->{'order'} ? "checked" : "";
printf "<input name=order size=6 value='%s'></td> </tr>\n",
	$cmd->{'order'} ? $cmd->{'order'} : '';

print "<tr> <td><b>",&hlink($text{'edit_noshow'},"noshow"),"</b></td>\n";
printf "<td><input type=radio name=noshow value=1 %s> %s\n",
	$cmd->{'noshow'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=noshow value=0 %s> %s</td>\n",
	$cmd->{'noshow'} ? "" : "checked", $text{'no'};

print "<td><b>",&hlink($text{'edit_usermin'},"usermin"),"</b></td>\n";
printf "<td><input type=radio name=usermin value=1 %s> %s\n",
	$cmd->{'usermin'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=usermin value=0 %s> %s</td> </tr>\n",
	$cmd->{'usermin'} ? "" : "checked", $text{'no'};

print "<tr> <td><b>",&hlink($text{'edit_timeout'},"timeout"),"</b></td>\n";
printf "<td><input type=radio name=timeout_def value=1 %s> %s\n",
	$cmd->{'timeout'} ? "" : "checked", $text{'edit_timeoutdef'};
printf "<input type=radio name=timeout_def value=0 %s>\n",
	$cmd->{'timeout'} ? "checked" : "";
printf "<input name=timeout size=6 value='%s'> %s</td>\n",
	$cmd->{'timeout'} ? $cmd->{'timeout'} : '', $text{'edit_secs'};

print "<td><b>",&hlink($text{'edit_clear'},"clear"),"</b></td>\n";
printf "<td><input type=radio name=clear value=1 %s> %s\n",
	$cmd->{'clear'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=clear value=0 %s> %s</td> </tr>\n",
	$cmd->{'clear'} ? "" : "checked", $text{'no'};

# Show Webmin servers to run on
@servers = &list_servers();
if (@servers > 1) {
	print "<tr> <td valign=top><b>",
		&hlink($text{'edit_servers'}, "servers"),"</b></td>\n";
	print "<td colspan=3>";
	@hosts = @{$cmd->{'hosts'}};
	@hosts = ( 0 ) if (!@hosts);
	print &ui_select("hosts", \@hosts,
	 [ map { [ $_->{'id'}, ($_->{'desc'} || $_->{'host'}) ] } @servers ],
	 5, 1);
	print "</td> </tr>\n";
	}

print "</table></td></tr></table><p>\n";

# Show parameters
&show_params_inputs($cmd);

print "<table width=100%><tr>\n";
print "<td><input type=submit value=\"$text{'save'}\"></td>\n";
if (!$in{'new'}) {
	print "<td align=right><input type=submit name=delete ",
	      "value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

