#!/usr/local/bin/perl
# edit_image.cgi
# Edit or create a boot partition

require './lilo-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");

&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'image_title1'}, "");
	$members = [ ];
	}
else {
	&ui_print_header(undef, $text{'image_title2'}, "");
	$conf = &get_lilo_conf();
	$image = $conf->[$in{'idx'}];
	$members = $image->{'members'};
	}

print "<form action=save_image.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'image_options'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'image_name'}</b></td>\n";
printf "<td><input name=label size=15 value='%s'></td>\n",
	&find_value("label", $members);

print "<td><b>$text{'image_kernel'}</b></td>\n";
printf "<td><input name=image size=25 value='%s'> %s</td> </tr>\n",
	$image->{'value'}, &file_chooser_button("image", 0);

print "<tr> <td><b>$text{'image_opts'}</b></td> <td colspan=3>\n";
$append = &find_value("append", $members);
$literal = &find_value("literal", $members);
$append =~ s/^"(.*)"$/$1/g;
$literal =~ s/^"(.*)"$/$1/g;
printf "<input type=radio name=opts value=0 %s> $text{'image_default'}\n",
	$append || $literal ? "" : "checked";
printf "<input type=radio name=opts value=1 %s> $text{'image_add'}\n",
	$append ? "checked" : "";
printf "<input type=radio name=opts value=2 %s> $text{'image_replace'}\n",
	$literal ? "checked" : "";
printf "&nbsp; <input name=append size=20 value='%s'></td> </tr>\n",
	$append ? $append : $literal;

print "<tr> <td><b>$text{'image_root'}</b></td> <td colspan=3>\n";
$root = &find_value("root", $members);
printf "<input type=radio name=rmode value=0 %s> $text{'image_fromkern'}\n",
	$root ? "" : "checked";
printf "<input type=radio name=rmode value=1 %s> $text{'image_rcurr'}\n",
	$root eq "current" ? "checked" : "";
printf "<input type=radio name=rmode value=2 %s> $text{'image_rdev'}\n",
	$root && $root ne "current" ? "checked" : "";
print &foreign_call("fdisk", "partition_select",
		    "root", $root eq "current" ? undef : $root, 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'image_initrd'}</b></td> <td colspan=3>\n";
$initrd = &find_value("initrd", $members);
printf "<input type=radio name=initrd_def value=1 %s> $text{'default'}\n",
	$initrd ? '' : 'checked';
printf "<input type=radio name=initrd_def value=0 %s>\n",
	$initrd ? 'checked' : '';
printf "<input name=initrd size=30 value='%s'> %s</td> </tr>\n",
	$initrd, &file_chooser_button("initrd");

$readonly = &find("read-only", $members);
$readwrite = &find("read-write", $members);
print "<tr> <td><b>$text{'image_mode'}</b></td> <td><select name=ro>\n";
printf "<option value=0 %s>$text{'image_fromkern'}</option>\n",
	$readonly || $readwrite ? "" : "selected";
printf "<option value=1 %s>$text{'image_ro'}</option>\n",
	$readonly ? "selected" : "";
printf "<option value=2 %s>$text{'image_rw'}</option>\n",
	$readwrite ? "selected" : "";
print "</select></td>\n";

$vga = lc(&find_value("vga", $members));
print "<td><b>$text{'image_vga'}</b></td>\n";
print "<td><select name=vga>\n";
printf "<option value='' %s>$text{'image_fromkern'}</option>\n",
	$vga ? "" : "selected";
printf "<option value=normal %s>80x25</option>\n",
	$vga eq "normal" ? "selected" : "";
printf "<option value=ext %s>80x50</option>\n",
	$vga eq "ext" || $vga eq "extended" ? "selected" : "";
printf "<option value=ask %s>$text{'image_ask'}</option>\n",
	$vga eq "ask" ? "selected" : "";
printf "<option value=other %s>$text{'image_other'}</option>\n",
	$vga =~ /\d/ ? "selected" : "";
printf "</select><input name=vgaother size=6 value='%s'></td> </tr>\n",
	$vga =~ /\d/ ? $vga : "";

$lock = &find("lock", $members);
print "<tr> <td><b>$text{'image_lock'}</b></td> <td>\n";
printf "<input type=radio name=lock value=1 %s> $text{'yes'}\n",
	$lock ? "checked" : "";
printf "<input type=radio name=lock value=0 %s> $text{'no'}</td>\n",
	$lock ? "" : "checked";

$optional = &find("optional", $members);
print "<td><b>$text{'image_optional'}</b></td> <td>\n";
printf "<input type=radio name=optional value=1 %s> $text{'yes'}\n",
	$optional ? "checked" : "";
printf "<input type=radio name=optional value=0 %s> $text{'no'}</td> </tr>\n",
	$optional ? "" : "checked";

$password = &find_value("password", $members);
print "<tr> <td><b>$text{'image_password'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=passmode value=0 %s> $text{'image_none'}\n",
	$password ? "" : "checked";
printf "<input type=radio name=passmode value=1 %s>\n",
	$password ? "checked" : "";
print "<input name=password size=25 value=\"$password\"></td> </tr>\n";

$restricted = &find("restricted", $members);
printf "<tr> <td><b>$text{'image_restricted'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=restricted value=1 %s> %s\n",
	$restricted ? "checked" : "", $text{'image_extra'};
printf "<input type=radio name=restricted value=0 %s> %s</td> </tr>\n",
	$restricted ? "" : "checked", $text{'image_any'};

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
print "<td align=left><input type=submit value=\"$text{'save'}\"></td>\n";
if (!$in{'new'}) {
	print "<td align=right>",
	      "<input type=submit name=delete value=\"$text{'delete'}\"></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

