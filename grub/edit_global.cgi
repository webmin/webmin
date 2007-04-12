#!/usr/local/bin/perl
# edit_global.cgi
# Edit global GRUB options

require './grub-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
$conf = &get_menu_config();
&ui_print_header(undef, $text{'global_title'}, "");

print "<form action=save_global.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'global_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$default = &find_value("default", $conf);
@titles = &find_value("title", $conf);
print "<tr> <td><b>$text{'global_default'}</b></td>\n";
print "<td><select name=default>\n";
printf "<option value='' %s>%s\n",
	$default eq '' ? 'selected' : '', $text{'global_first'};
for($i=0; $i<@titles; $i++) {
	printf "<option value=%s %s>%s\n",
		$i, $default eq $i ? 'selected' : '', $titles[$i];
	}
print "</select></td>\n";

$fallback = &find_value("fallback", $conf);
print "<td><b>$text{'global_fallback'}</b></td>\n";
print "<td><select name=fallback>\n";
printf "<option value='' %s>%s\n",
	$fallback eq '' ? 'selected' : '', $text{'global_first'};
for($i=0; $i<@titles; $i++) {
	printf "<option value=%s %s>%s\n",
		$i, $fallback eq $i ? 'selected' : '', $titles[$i];
	}
print "</select></td> </tr>\n";

$timeout = &find_value("timeout", $conf);
print "<tr> <td><b>$text{'global_timeout'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=timeout_def value=1 %s> %s\n",
	$timeout eq '' ? 'checked' : '', $text{'global_forever'};
printf "<input type=radio name=timeout_def value=0 %s>\n",
	$timeout eq '' ? '' : 'checked';
printf "<input name=timeout size=5 value='%s'> %s</td> </tr>\n",
	$timeout, $text{'global_secs'};

$password = &find("password", $conf);
@pv = split(/\s+/, $password->{'value'}) if ($password);
print "<tr> <td valign=top><b>$text{'global_password'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=password_def value=1 %s> %s\n",
	$password eq '' ? 'checked' : '', $text{'global_none'};
printf "<input type=radio name=password_def value=0 %s>\n",
	$password eq '' ? '' : 'checked';
printf "<input name=password size=20 value='%s'><br>\n", $pv[0];
printf "<input type=checkbox name=password_file %s> %s\n",
	$pv[1] ? "checked" : "", $text{'global_password_file'}; 
printf "<input name=password_filename size=30 value='%s'></td> </tr>\n", $pv[1];

$r = $config{'install'};
$dev = &bios_to_linux($r);
$sel = &foreign_call("fdisk", "partition_select", "install", $dev, 2, \$found);
print "<td><b>$text{'global_install'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=install_mode value=1 %s> %s %s\n",
	$found ? 'checked' : '', $text{'global_sel'}, $sel;
printf "<input type=radio name=install_mode value=0 %s> %s\n",
	$found ? '' : 'checked', $text{'global_other'};
printf "<input name=other size=10 value='%s'></td> </tr>\n",
	$found ? '' : $r;

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

