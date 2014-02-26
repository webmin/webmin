#!/usr/local/bin/perl
# edit_dev.cgi
# Display burner device options

require './burner-lib.pl';
$access{'global'} || &error($text{'dev_ecannot'});
&ui_print_header(undef, $text{'dev_title'}, "");

print "<form action=save_dev.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'dev_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'dev_device'}</b></td>\n";
print "<td><select name=dev>\n";
if (!$config{'dev'}) {
	print "<option value='' checked>$text{'dev_none'}</option>\n";
	}
foreach $d (&list_cdrecord_devices()) {
	printf "<option value=%s %s>%s (%s)</option>\n",
		$d->{'dev'}, $d->{'dev'} eq $config{'dev'} ? 'selected' : '',
		$d->{'name'}, $d->{'type'};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'dev_speed'}</b></td> <td>\n";
foreach $s (1, 2, 4, 8, 16, 32, 48, undef) {
	printf "&nbsp;&nbsp;<input type=radio name=speed value=%s %s> %s\n",
		$s, $s eq $config{'speed'} ? 'checked' : '',
		$s ? $s.'x' : $text{'dev_other'};
	$found++ if ($s eq $config{'speed'});
	}
printf "<input name=other size=4 value='%s'></td> </tr>\n",
	$found ? '' : $config{'speed'};

print "<tr> <td><b>$text{'dev_extra'}</b></td>\n";
printf "<td><input name=extra size=40 value='%s'></td> </tr>\n",
	$config{'extra'};

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

