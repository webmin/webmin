#!/usr/local/bin/perl
# edit_anon.cgi
# Display anonymous FTP options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'anon_title'}, "", "anon");

$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

if (!getpwnam("ftp")) {
	print "<b>$text{'anon_eftp'}</b> <p>\n";
	}

print "<form action=save_anon.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'anon_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display anonymous-root options
@root = ( &find_value('anonymous-root', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'anon_root'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'anon_dir'}</b></td>\n",
      "<td><b>$text{'anon_class'}</b></td> </tr>\n";
$i = 0;
foreach $r (@root) {
	print "<tr $cb>\n";
	printf "<td><input name=dir_$i size=35 value='%s'> %s</td>\n",
		$r->[0], &file_chooser_button("dir_$i", 1);
	print "<td><select name=class_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$r->[1] ? '' : 'selected', $text{'anon_any'};
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$r->[1] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

# Display guest-root options
@root = ( &find_value('guest-root', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'anon_groot'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'anon_dir'}</b></td>\n",
      "<td><b>$text{'anon_uids'}</b></td> </tr>\n";
$i = 0;
foreach $r (@root) {
	print "<tr $cb>\n";
	printf "<td><input name=gdir_$i size=35 value='%s'> %s</td>\n",
		$r->[0], &file_chooser_button("gdir_$i", 1);
	printf "<td><input name=uids_$i size=20 value='%s'> %s</td>\n",
		join(" ", @$r[1..@$r-1]),
		&user_chooser_button("uids_$i", 1);
	print "</tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display autogroup options
@auto = ( &find_value('autogroup', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'anon_auto'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'anon_group'}</b></td>\n",
      "<td><b>$text{'anon_classes'}</b></td> </tr>\n";
$i = 0;
foreach $a (@auto) {
	local %aclass;
	map { $aclass{$_}++ } @$a[1..@$a-1];
	print "<tr $cb>\n";
	print "<td><input name=agroup_$i size=8 value='$a->[0]'> ",
		&group_chooser_button("agroup_$i"),"</td>\n";
	print "<td>\n";
	foreach $c (@class) {
		printf "<input name=aclass_$i type=checkbox %s value=%s> %s\n",
			$aclass{$c->[0]} ? 'checked' : '', $c->[0], $c->[0];
		}
	print "</td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display passwd-check field
$p = &find_value('passwd-check', $conf);
print "<tr> <td><b>$text{'anon_passwd'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=passwd_def value=1 %s> %s\n",
	$p ? '' : 'checked',  $text{'default'};
printf "<input type=radio name=passwd_def value=0 %s>\n",
	$p ? 'checked' : '';
print "<select name=level>\n";
foreach $l ('none', 'trivial', 'rfc822') {
	printf "<option %s value='%s'>%s</option>\n",
		$p->[0] eq $l ? 'selected' : '', $l, $text{"anon_$l"};
	}
print "</select> <select name=action>\n";
foreach $a ('enforce', 'warn') {
	printf "<option %s value='%s'>%s</option>\n",
		$p->[1] eq $a ? 'selected' : '', $a, $text{"anon_$a"};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'anon_email'}</b></td>\n";
printf "<td colspan=3><input name=email size=50 value='%s'></td> </tr>\n",
	join(" ", map { $_->[0] } &find_value('deny-email', $conf));

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

