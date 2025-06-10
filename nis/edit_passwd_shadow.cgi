#!/usr/local/bin/perl
# edit_passwd_shadow.cgi
# Edit a NIS password/shadow files entry

require './nis-lib.pl';
use Time::Local;
&ReadParse();
&ui_print_header(undef, $text{'passwd_title'}, "");
$mode = ($0 =~ /passwd_shadow_full.cgi$/ ? 2 :
	 $0 =~ /passwd_shadow.cgi$/ ? 1 : 0);

# Build list of available shells
@shlist = ("/bin/sh", "/bin/csh", "/bin/false");
open(SHELLS, "</etc/shells");
while(<SHELLS>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	push(@shlist, $_) if (/\S/);
	}
close(SHELLS);

($t, $lnums, $passwd, $shadow) =
	&table_edit_setup($in{'table'}, $in{'line'}, ':');
print "<form action=save_passwd_shadow.cgi method=post>\n";
print "<input type=hidden name=table value='$in{'table'}'>\n";
print "<input type=hidden name=line value='$in{'line'}'>\n";
print "<input type=hidden name=mode value='$mode'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'passwd_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'passwd_name'}</b></td>\n";
print "<td><input name=name size=10 value=\"$passwd->[0]\"></td>\n";

print "<td><b>$text{'passwd_uid'}</b></td>\n";
print "<td><input name=uid size=10 value=\"$passwd->[2]\"></td> </tr>\n";

print "<tr> <td><b>$text{'passwd_real'}</b></td>\n";
print "<td><input name=real size=20 value=\"$passwd->[4]\"></td>\n";

print "<td><b>$text{'passwd_home'}</b></td>\n";
print "<td><input name=home size=25 value=\"$passwd->[5]\"> ",
      &file_chooser_button("home", 1),"</td> </tr>\n";

print "<tr> <td valign=top><b>$text{'passwd_shell'}</b></td>\n";
print "<td valign=top><select name=shell>\n";
foreach $s (&unique(@shlist)) {
	printf "<option %s>%s</option>\n",
		$passwd->[6] eq $s ? 'selected' : '', $s;
	$found++ if ($passwd->[6] eq $s);
	}
printf "<option value='' %s>%s</option>\n",
	$found ? '' : 'selected', $text{'passwd_other'};
print "</select><br>\n";
printf "<input name=other size=20 value='%s'> %s</td>\n",
	$found ? '' : $passwd->[6], &file_chooser_button("other");

$pass = $mode ? $shadow->[1] : $passwd->[1];
%uconfig = &foreign_config("useradmin");
print "<td valign=top rowspan=2><b>$text{'passwd_pass'}</b></td> <td rowspan=2>\n";
printf"<input type=radio name=passmode value=0 %s> %s<br>\n",
	$pass eq "" ? "checked" : "",
	$uconfig{'empty_mode'} ? $text{'passwd_none1'} : $text{'passwd_none2'};
printf"<input type=radio name=passmode value=1 %s> $text{'passwd_nologin'}<br>\n",
	$pass eq $uconfig{'lock_string'} ? "checked" : "";
print "<input type=radio name=passmode value=3> $text{'passwd_clear'}\n";
printf "<input %s name=pass size=15><br>\n",
	$uconfig{'passwd_stars'} ? "type=password" : "";
printf "<input type=radio name=passmode value=2 %s> $text{'passwd_encrypted'}\n",
	$pass && $pass ne $uconfig{'lock_string'} ? "checked" :"";
printf "<input name=encpass size=13 value=\"%s\">\n",
	$pass && $pass ne $uconfig{'lock_string'} ? $pass : "";
print "</td> </tr>\n";

print "<tr> <td><b>$text{'passwd_gid'}</b></td>\n";
print "<td><input name=gid size=10 value='$passwd->[3]'></td> </tr>\n";

if ($mode == 2) {
	print "</table></td></tr></table><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'passwd_header2'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'passwd_change'}</b></td>\n";
	if ($shadow->[2] && $shadow->[2] >= 0) {
		@tm = localtime(timelocal(gmtime($shadow->[2] * 60*60*24)));
		printf "<td>%s/%s/%s</td>\n",
			$tm[3], $text{"smonth_".($tm[4]+1)}, $tm[5]+1900;
		}
	elsif ($in{'line'} eq "") { print "<td>$text{'passwd_never'}</td>\n"; }
	else { print "<td>$text{'passwd_unknown'}</td>\n"; }

	print "<td><b>$text{'passwd_expire'}</b></td>\n";
	if ($shadow->[7] && $shadow->[7] >= 0) {
		@tm = localtime($shadow->[7] * 60*60*24);
		$eday = $tm[3];
		$emon = $tm[4]+1;
		$eyear = $tm[5]+1900;
		}
	print "<td>";
	&date_input($eday, $emon, $eyear, 'expire');
	print "</td>\n";

	print "<tr> <td><b>$text{'passwd_min'}</b></td>\n";
	printf "<td><input size=5 name=min value=\"%s\"></td>\n",
		$shadow->[3] < 0 ? "" : $shadow->[3];

	print "<td><b>$text{'passwd_max'}</b></td>\n";
	printf "<td><input size=5 name=max value=\"%s\"></td></tr>\n",
		$shadow->[4] < 0 ? "" : $shadow->[4];

	print "<tr> <td><b>$text{'passwd_warn'}</b></td>\n";
	printf "<td><input size=5 name=warn value=\"%s\"></td>\n",
		$shadow->[5] < 0 ? "" : $shadow->[5];

	print "<td><b>$text{'passwd_inactive'}</b></td>\n";
	printf "<td><input size=5 name=inactive value=\"%s\"></td></tr>\n",
		$shadow->[6] < 0 ? "" : $shadow->[6];
	}
print "</table></td></tr></table>\n";

if (defined($in{'line'})) {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
else {
	print "<input type=submit value='$text{'create'}'>\n";
	}
print "</form>\n";
&ui_print_footer("edit_tables.cgi?table=$in{'table'}", $text{'tables_return'},
	"", $text{'index_return'});

