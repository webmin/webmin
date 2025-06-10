#!/usr/local/bin/perl
# edit_secret.cgi
# Displays a form for editing or creating a pap secret

require './pap-lib.pl';
$access{'secrets'} || &error($text{'secrets_ecannot'});
if (@ARGV) {
	$idx = $ARGV[0];
	&ui_print_header(undef, $text{'edit_secret_etitle'}, "");
	@seclist = &list_secrets();
	%sec = %{$seclist[$idx]};
	}
else {
	&ui_print_header(undef, $text{'edit_secret_ctitle'}, "");
	}

print "<form action=save_secret.cgi>\n";
if (%sec) { print "<input type=hidden name=idx value=$idx>\n"; }
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",$text{'edit_secret_acc'},"</b></td> </tr>\n";
print "<tr $cb> <td><table widht=100%>\n";

print "<tr $cb> <td><b>", $text{'edit_secret_user'}, "</b></td>\n";
printf "<td><input type=radio name=client_def value=1 %s> ",
	%sec && !$sec{'client'} ? "checked" : "";
print $text{'edit_secret_uany'}, "\n";
printf "<input type=radio name=client_def value=0 %s> ",
	%sec && !$sec{'client'} ? "" : "checked";
print "<input name=client size=20 value=\"$sec{'client'}\"></td>\n";

print "<td><b>",$text{'edit_secret_serv'},"</b></td>\n";
printf "<td><input type=radio name=server_def value=1 %s> ",
	$sec{'server'} eq "*" ? "checked" : "";
print $text{'edit_secret_sany'},"\n";
printf "<input type=radio name=server_def value=0 %s> ",
	$sec{'server'} eq "*" ? "" : "checked";
printf "<input name=server size=20 value=\"%s\"></td> </tr>\n",
	$sec{'server'} eq "*" ? "" : $sec{'server'};

print "<tr $cb> <td valign=top><b>", $text{'edit_secret_pass'}, "</b></td>\n";
printf "<td valign=top><input type=radio name=pass_mode value=0 %s> ",
	%sec && $sec{'secret'} eq "" ? "checked" : "";
print $text{'edit_secret_none'}, "<br>\n";
printf "<input type=radio name=pass_mode value=1 %s> ",
	$sec{'secret'} =~ /^@(.*)$/ ? "checked" : "";
print $text{'edit_secret_ffile'};
printf "<input name=pass_file size=20 value=\"%s\">\n",
	$sec{'secret'} =~ /^@(.*)$/ ? $1 : "";
print &file_chooser_button("pass_file", 0);
print "<br>\n";
if (%sec) {
	printf "<input type=radio name=pass_mode value=2 %s> ",
		$sec{'secret'} !~ /^(@.*|)$/ ? "checked" : "";
	print $text{'edit_secret_leave'}, "<br>\n";
	}
printf "<input type=radio name=pass_mode value=3 %s> ",
	%sec ? "" : "checked";
print $text{'edit_secret_setto'}, "\n";
print "<input type=password name=pass_text size=15></td>\n";

@ips = @{$sec{'ips'}};
print "<td valign=top><b>", $text{'edit_secret_vaddr'}, "</b></td>\n";
printf "<td><input type=radio name=ips_mode value=0 %s> ",
	$ips[0] eq "*" || !@ips ? "checked" : "";
print $text{'edit_secret_aany'}, "<br>\n";
printf "<input type=radio name=ips_mode value=1 %s> ",
	$ips[0] eq "-" ? "checked" : "";
print $text{'edit_secret_anone'}, "<br>\n";
printf "<input type=radio name=ips_mode value=2 %s> ",
	@ips && $ips[0] ne "-" && $ips[0] ne "*" ? "checked" : "";
print $text{'edit_secret_alist'}, "<br>\n";
printf "<textarea name=ips rows=5 cols=20>%s</textarea></td> </tr>\n",
	@ips && $ips[0] ne "-" && $ips[0] ne "*" ? join("\n", @ips) : "";

print "</table></td></tr></table>\n";

print "<table width=100%><tr><td align=left>\n";
print "<input type=submit value=", $text{'edit_secret_save'}, "></td>\n";
if (%sec) {
	print "<td align=right>\n";
	print "<input type=submit name=delete value=", $text{'edit_secret_del'},
	      "></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_secrets.cgi", $text{'edit_secret_return'});

