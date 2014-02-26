#!/usr/local/bin/perl
# edit_misc.cgi
# Display miscellaneous options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'misc_title'}, "", "misc");

$conf = &get_ftpaccess();
@class = &find_value("class", $conf);

print "<form action=save_misc.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'misc_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display ls* options
foreach $l ('lslong', 'lsshort', 'lsplain') {
	$v = &find_value($l, $conf);
	print "<tr> <td><b>",$text{"misc_$l"},"</b></td> <td colspan=3>\n";
	printf "<input type=radio name=%s_def value=1 %s> %s\n",
		$l, $v ? '' : 'checked', $text{'default'};
	printf "<input type=radio name=%s_def value=0 %s>\n",
		$l, $v ? 'checked' : '';
	printf "<input name=%s size=30 value='%s'></td> </tr>\n",
		$l, join(" ", @$v);
	}

# Display shutdown option
$s = &find_value('shutdown', $conf);
printf "<tr> <td><b>$text{'misc_shutdown'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=shutdown_def value=1 %s> %s\n",
	$s ? '' : 'checked', $text{'misc_none'};
printf "<input type=radio name=shutdown_def value=0 %s>\n",
	$s ? 'checked' : '';
printf "<input name=shutdown size=30 value='%s'> %s</td> </tr>\n",
	$s->[0], &file_chooser_button('shutdown', 0);
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display nice option
@nice = ( &find_value('nice', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'misc_nice'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'misc_ndelta'}</b></td> ",
      "<td><b>$text{'misc_class'}</b></td> </tr>\n";
$i = 0;
foreach $n (@nice) {
	print "<tr $cb>\n";
	print "<td><input name=ndelta_$i size=5 value='$n->[0]'></td>\n";
	print "<td><select name=nclass_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$n->[1] ? '' : 'checked', $text{'misc_all'};
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$n->[1] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td> </tr>\n";
	$i++;
	}
print "</table></td>\n";
print "<tr> <td colspan=4><hr></td> </tr>\n";

# Display defumask option
@umask = ( &find_value('defumask', $conf), [ ] );
print "<tr> <td valign=top><b>$text{'misc_defumask'}</b></td>\n";
print "<td colspan=3><table border>\n";
print "<tr $tb> <td><b>$text{'misc_umask'}</b></td> ",
      "<td><b>$text{'misc_class'}</b></td> </tr>\n";
$i = 0;
foreach $u (@umask) {
	print "<tr $cb>\n";
	print "<td><input name=umask_$i size=5 value='$u->[0]'></td>\n";
	print "<td><select name=uclass_$i>\n";
	printf "<option value='' %s>%s</option>\n",
		$u->[1] ? '' : 'checked', $text{'misc_all'};
	foreach $c (@class) {
		printf "<option %s>%s</option>\n",
			$u->[1] eq $c->[0] ? 'selected' : '', $c->[0];
		}
	print "</select></td> </tr>\n";
	$i++;
	}
print "</table></td>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

