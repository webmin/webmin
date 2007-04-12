#!/usr/local/bin/perl
# edit_title.cgi
# Display menu option details

require './grub-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
&ReadParse();
$conf = &get_menu_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'title_add'}, "");
	}
else {
	&ui_print_header(undef, $text{'title_edit'}, "");
	$title = $conf->[$in{'idx'}];
	}

print "<form action=save_title.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'title_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'title_title'}</b></td>\n";
printf "<td colspan=3><input name=title size=35 value='%s'></td> </tr>\n",
	$title->{'value'};

$r = $title->{'root'} || $title->{'rootnoverify'};
if (!$r) {
	$mode = 0;
	}
elsif ($dev = &bios_to_linux($r)) {
	$mode = 2;
	}
else {
	$mode = 1;
	}
$sel = &foreign_call("fdisk", "partition_select", "root", $dev, 2, \$found);
if (!$found && $mode == 2) {
	$mode = 1;
	}

print "<td><b>$text{'title_root'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=root_mode value=0 %s> %s\n",
	$mode == 0 ? 'checked' : '', $text{'default'};
printf "<input type=radio name=root_mode value=2 %s> %s %s\n",
	$mode == 2 ? 'checked' : '', $text{'title_sel'}, $sel;
printf "<input type=radio name=root_mode value=1 %s> %s\n",
	$mode == 1 ? 'checked' : '', $text{'title_other'};
printf "<input name=other size=10 value='%s'><br>\n",
	$mode == 1 ? $title->{'root'} : '';

print "&nbsp;" x 3;
printf "<input type=checkbox name=noverify value=1 %s> %s</td> </tr>\n",
	$title->{'rootnoverify'} ? "checked" : "", $text{'title_noverify'};

$boot = $title->{'chainloader'} ? 1 :
	$title->{'kernel'} ? 2 : 0;
if ($boot == 2) {
	$title->{'kernel'} =~ /^(\S+)\s*(.*)$/;
	$kernel = $1; $args = $2;
	}
print "<tr> <td valign=top><b>$text{'title_boot'}</b></td> <td colspan=3>\n";
print "<table width=100%>\n";

printf "<tr> <td valign=top><input type=radio name=boot_mode value=2 %s> %s</td>\n",
	$boot == 2 ? 'checked' : '', $text{'title_kernel'};
printf "<td>%s <input name=kernel size=40 value='%s'> %s<br>\n",
	$text{'title_kfile'}, $kernel;
printf "%s <input name=args size=40 value='%s'><br>\n",
	$text{'title_args'}, $args;
printf "%s <input type=radio name=initrd_def value=1 %s> %s\n",
	$text{'title_initrd'}, $title->{'initrd'} ? "" : "checked", 
	$text{'global_none'};
printf "<input type=radio name=initrd_def value=0 %s>\n",
	$title->{'initrd'} ? "checked" : "";
printf "<input name=initrd size=30 value='%s'></td> </tr>\n",
	$title->{'initrd'};

$chain = $title->{'chainloader'};
printf "<tr> <td valign=top><input type=radio name=boot_mode value=1 %s> %s</td>\n",
	$boot == 1 ? 'checked' : '', $text{'title_chain'};
printf "<td><input type=radio name=chain_def value=1 %s> %s<br>\n",
	$chain eq '+1' || !$chain ? 'checked' : '',
	$text{'title_chain_def'};
printf "<input type=radio name=chain_def value=0 %s> %s\n",
	$chain eq '+1' || !$chain ? '' : 'checked',
	$text{'title_chain_file'};
printf "<input name=chain size=40 value='%s'><br>\n",
	$chain eq '+1' ? '' : $chain;
printf "<input type=checkbox name=makeactive value=1 %s> %s</td> </tr>\n",
	defined($title->{'makeactive'}) ? 'checked' : '',
	$text{'title_makeactive'};

printf "<tr> <td colspan=2><input type=radio name=boot_mode value=0 %s> %s</td> </tr>\n",
	$boot == 0 ? 'checked' : '', $text{'title_none'};

print "</table></td> </tr>\n";

print "<tr> <td><b>$text{'title_lock'}</b></td>\n";
printf "<td><input type=radio name=lock value=1 %s> %s\n",
	defined($title->{'lock'}) ? "checked" : "", $text{'yes'};
printf "<input type=radio name=lock value=0 %s> %s</td> </tr>\n",
	defined($title->{'lock'}) ? "" : "checked", $text{'no'};

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td align=left><input type=submit value=\"$text{'save'}\"></td>\n";
if (!$in{'new'}) {
	print "<td align=right>",
	     "<input type=submit name=delete value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

