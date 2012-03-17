#!/usr/local/bin/perl
# conf_pass.cgi
# Display password options options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcp'}") unless $access{'conf_pass'};

&ui_print_header(undef, $text{'passwd_title'}, "");

&get_share("global");

print "<form action=save_pass.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'passwd_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<tr> <td><b>$text{'passwd_encrypt'}</b></td>\n";
printf "<td><input type=radio name=encrypt_passwords value=yes %s> $text{'yes'}\n",
	&istrue("encrypt passwords") ? "checked" : "";
printf "&nbsp; <input type=radio name=encrypt_passwords value=no %s> $text{'no'}</td>\n",
	&istrue("encrypt passwords") ? "" : "checked";

print "<td><b>$text{'passwd_allownull'}</b></td>\n";
printf "<td><input type=radio name=null_passwords value=yes %s> $text{'yes'}\n",
	&istrue("null passwords") ? "checked" : "";
printf "$gap <input type=radio name=null_passwords value=no %s> $text{'no'}</td></tr>\n",
	&istrue("null passwords") ? "" : "checked";

print "<tr> <td><b>$text{'passwd_program'}</b></td>\n";
printf "<td><input type=radio name=passwd_program_def value=1 %s> $text{'default'}\n",
	&getval("passwd program") eq "" ? "checked" : "";
printf "<input type=radio name=passwd_program_def value=0 %s>\n",
	&getval("passwd program") eq "" ? "" : "checked";
printf "<input size=15 name=passwd_program value=\"%s\"></td>\n",
	&getval("passwd program");

print "<td><b>$text{'passwd_sync'}</b></td>\n";
printf "<td><input type=radio name=unix_password_sync value=yes %s> $text{'yes'}\n",
	&istrue("unix password sync") ? "checked" : "";
printf "$gap <input type=radio name=unix_password_sync value=no %s> $text{'no'}</td></tr>\n",
	&istrue("unix password sync") ? "" : "checked";

print "<tr> <td valign=top><b>$text{'passwd_chat'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=passwd_chat_def value=1 %s> $text{'default'}\n",
	&getval("passwd chat") eq "" ? "checked" : "";
printf "<input type=radio name=passwd_chat_def value=0 %s> $text{'passwd_below'}<br>\n",
	&getval("passwd chat") eq "" ? "" : "checked";
print "<table border> <tr><td><b>$text{'passwd_waitfor'}</b></td> <td><b>$text{'passwd_send'}</b></td></tr>\n";
$pc = &getval("passwd chat");
while($pc =~ /^"([^"]*)"\s*(.*)/ || $pc =~ /^(\S+)\s*(.*)/) {
	if ($send) { push(@send, $1); $send = 0; }
	else { push(@recv, $1); $send = 1; }
	$pc = $2;
	}
for($i=0; $i<(@recv < 5 ? 5 : @recv+1); $i++) {
	printf "<tr><td><input name=chat_recv_$i value=\"%s\" size=20></td>\n",
		$recv[$i] eq "." ? "" : $recv[$i];
	printf "<td><input name=chat_send_$i value=\"%s\" size=20></td></tr>\n",
		$send[$i];
	}
print "</table></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'passwd_map'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=username_map_def value=1 %s> $text{'config_none'}\n",
	&getval("username map") eq "" ? "checked" : "";
printf"<input type=radio name=username_map_def value=0 %s> $text{'passwd_below'}<br>\n",
	&getval("username map") eq "" ? "" : "checked";
print "<table border> <tr><td><b>$text{'passwd_unixuser'}</b></td>\n";
print "                   <td><b>$text{'passwd_winuser'}</b></td></tr>\n";
open(UMAP, &getval("username map"));
while(<UMAP>) {
	s/\r|\n//g;
	s/[#;].*$//g;
	if (/^\s*(\S+)\s*=\s*(.*)$/) {
		local $uunix = $1;
		local $rest = $2;
		while($rest =~ /^\s*"([^"]*)"(.*)$/ ||
		      $rest =~ /^\s*(\S+)(.*)$/) {
			push(@uunix, $uunix);
			push(@uwin, $1);
			$rest = $2;
			}
		}
	}
close(UMAP);
for($i=0; $i<@uunix+1; $i++) {
	printf "<tr> <td><input name=umap_unix_$i size=8 value=\"%s\"></td>\n",
		$uunix[$i];
	printf "<td><input name=umap_win_$i size=30 value=\"%s\"></td> </tr>\n",
		$uwin[$i];
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=$text{'save'}></form>\n";

&ui_print_footer("", $text{'index_sharelist'});
