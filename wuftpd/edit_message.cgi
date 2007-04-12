#!/usr/local/bin/perl
# edit_message.cgi
# Display messages and readmes

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'message_title'}, "", "message");

$conf = &get_ftpaccess();

print "<form action=save_message.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'message_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@message = ( &find_value("message", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'message_message'}</b></td>\n";
print "<td><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'message_path'}</b></td>\n",
      "<td><b>$text{'message_when'}</b></td>\n",
      "<td><b>$text{'message_classes'}</b></td> </tr>\n";
$i = 0;
foreach $m (@message) {
	print "<tr $cb>\n";
	print "<td><input name=mpath_$i size=15 value='$m->[0]'></td>\n";
	printf "<td nowrap><input name=mwhen_$i type=radio value=0 %s> %s\n",
		$m->[1] =~ /^login$/i ? 'checked' : '',
		$text{'message_login'};
	printf "<input name=mwhen_$i type=radio value=1 %s> %s\n",
		$m->[1] =~ /^cwd=\*$/ ? 'checked' : '',
		$text{'message_alldir'};
	printf "<input name=mwhen_$i type=radio value=2 %s> %s\n",
		$m->[1] =~ /^cwd=([^\*].*)$/ ? 'checked' : '',
		$text{'message_dir'};
	printf "<input name=mcwd_$i size=20 value='%s'></td>\n",
		$m->[1] =~ /^cwd=([^\*].*)$/ ? $1 : '';
	printf "<td><input name=mclasses_$i size=15 value='%s'></td>\n",
		join(" ", @$m[2..@$m-1]);
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=2><hr></td> </tr>\n";

@readme = ( &find_value("readme", $conf), [ ] );
print "<tr> <td valign=top><b>$text{'message_readme'}</b></td>\n";
print "<td><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'message_path'}</b></td>\n",
      "<td><b>$text{'message_update'}</b></td>\n",
      "<td><b>$text{'message_classes'}</b></td> </tr>\n";
$i = 0;
foreach $m (@readme) {
	print "<tr $cb>\n";
	print "<td><input name=rpath_$i size=15 value='$m->[0]'></td>\n";
	printf "<td nowrap><input name=rwhen_$i type=radio value=0 %s> %s\n",
		$m->[1] =~ /^login$/i ? 'checked' : '',
		$text{'message_login'};
	printf "<input name=rwhen_$i type=radio value=1 %s> %s\n",
		$m->[1] =~ /^cwd=\*$/ ? 'checked' : '',
		$text{'message_alldir'};
	printf "<input name=rwhen_$i type=radio value=2 %s> %s\n",
		$m->[1] =~ /^cwd=([^\*].*)$/ ? 'checked' : '',
		$text{'message_dir'};
	printf "<input name=rcwd_$i size=20 value='%s'></td>\n",
		$m->[1] =~ /^cwd=([^\*].*)$/ ? $1 : '';
	printf "<td><input name=rclasses_$i size=15 value='%s'></td>\n",
		join(" ", @$m[2..@$m-1]);
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=2><hr></td> </tr>\n";

$g = &find_value('greeting', $conf);
print "<tr> <td><b>$text{'message_greeting'}</b></td>\n";
printf "<td><input type=radio name=greeting value=full %s> %s\n",
	$g->[0] eq 'full' || !$g->[0] ? 'checked' : '', $text{'message_full'};
printf "<input type=radio name=greeting value=brief %s> %s\n",
	$g->[0] eq 'brief' ? 'checked' : '', $text{'message_brief'};
printf "<input type=radio name=greeting value=terse %s> %s</td> </tr>\n",
	$g->[0] eq 'terse' ? 'checked' : '', $text{'message_terse'};

$b = &find_value('banner', $conf);
print "<tr> <td><b>$text{'message_banner'}</b></td>\n";
printf "<td><input type=radio name=banner_def value=1 %s> %s\n",
	$b ? '' : 'checked', $text{'message_none'};
printf "<input type=radio name=banner_def value=0 %s> %s\n",
	$b ? 'checked' : '', $text{'message_file'};
printf "<input name=banner size=30 value='%s'> %s</td> </tr>\n",
	$b->[0], &file_chooser_button('banner', 0);

$h = &find_value('hostname', $conf);
print "<tr> <td><b>$text{'message_hostname'}</b></td>\n";
printf "<td><input type=radio name=hostname_def value=1 %s> %s\n",
	$h ? '' : 'checked', $text{'message_hostdef'};
printf "<input type=radio name=hostname_def value=0 %s>\n",
	$h ? 'checked' : '';
printf "<input name=hostname size=30 value='%s'> %s</td> </tr>\n",
	$h->[0];

$e = &find_value('email', $conf);
print "<tr> <td><b>$text{'message_email'}</b></td>\n";
printf "<td><input type=radio name=email_def value=1 %s> %s\n",
	$e ? '' : 'checked', $text{'default'};
printf "<input type=radio name=email_def value=0 %s>\n",
	$e ? 'checked' : '';
printf "<input name=email size=30 value='%s'> %s</td> </tr>\n",
	$e->[0];

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

