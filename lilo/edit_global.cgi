#!/usr/local/bin/perl
# edit_global.cgi
# Display options that apply to all sections

require './lilo-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");

&ui_print_header(undef, $text{'global_title'}, "");
$conf = &get_lilo_conf();

print "<form action=save_global.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'global_desc'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$boot = &find_value("boot", $conf);
print "<tr> <td><b>$text{'global_boot'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=bootmode value=0 %s> $text{'global_root'}\n",
	$boot ? "" : "checked";
printf "<input type=radio name=bootmode value=1 %s>\n",
	$boot ? "checked" : "";
print &foreign_call("fdisk", "partition_select", "boot", $boot, 2);
print "</td> </tr>\n";

$default = &find_value("default", $conf);
print "<tr> <td><b>$text{'global_default'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=defaultmode value=0 %s> $text{'global_first'}\n",
	$default ? "" : "checked";
printf "<input type=radio name=defaultmode value=1 %s>\n",
	$default ? "checked" : "";
print "<select name=default>\n";
@images = sort { $a->{'index'} <=> $b->{'index'} }
	       ( &find("image", $conf), &find("other", $conf) );
foreach $i (@images) {
	$l = &find_value("label", $i->{'members'});
	if ($l) {
		printf "<option %s>$l</option>\n",
			$default eq $l ? "selected" : "";
		}
	}
print "</select></td> </tr>\n";

$prompt = &find("prompt", $conf);
print "<tr> <td><b>$text{'global_prompt'}</b></td> <td>\n";
printf "<input type=radio name=prompt value=1 %s> $text{'yes'}\n",
	$prompt ? "checked" : "";
printf "<input type=radio name=prompt value=0 %s> $text{'no'}</td>\n",
	$prompt ? "" : "checked";

$timeout = &find_value("timeout", $conf);
print "<td><b>$text{'global_timeout'}</b></td> <td>\n";
printf "<input type=radio name=timeout_def value=1 %s> %s\n",
	$timeout ? "" : "checked", $text{'global_forever'};
printf "<input type=radio name=timeout_def value=0 %s>\n",
	$timeout ? "checked" : "";
printf "<input name=timeout size=5 value='%s'> $text{'global_secs'}</td> </tr>\n",
	$timeout ? $timeout / 10.0 : "";

$lock = &find("lock", $conf);
print "<tr> <td><b>$text{'global_lock'}</b></td> <td>\n";
printf "<input type=radio name=lock value=1 %s> $text{'yes'}\n",
	$lock ? "checked" : "";
printf "<input type=radio name=lock value=0 %s> $text{'no'}</td>\n",
	$lock ? "" : "checked";

$delay = &find_value("delay", $conf);
print "<td><b>$text{'global_delay'}</b></td> <td>\n";
printf "<input type=radio name=delay_def value=1 %s> $text{'global_imm'}\n",
	$delay ? "" : "checked";
printf "<input type=radio name=delay_def value=0 %s>\n",
	$delay ? "checked" : "";
printf "<input name=delay size=5 value='%s'> $text{'global_secs'}</td> </tr>\n",
	$delay ? $delay / 10.0 : "";

$compact = &find("compact", $conf);
print "<tr> <td><b>$text{'global_compact'}</b></td> <td>\n";
printf "<input type=radio name=compact value=1 %s> $text{'yes'}\n",
	$compact ? "checked" : "";
printf "<input type=radio name=compact value=0 %s> $text{'no'}</td>\n",
	$compact ? "" : "checked";

$optional = &find("optional", $conf);
print "<td><b>$text{'global_optional'}</b></td> <td>\n";
printf "<input type=radio name=optional value=1 %s> $text{'yes'}\n",
	$optional ? "checked" : "";
printf "<input type=radio name=optional value=0 %s> $text{'no'}</td> </tr>\n",
	$optional ? "" : "checked";

$password = &find_value("password", $conf);
print "<tr> <td><b>$text{'global_password'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=passmode value=0 %s> $text{'global_none'}\n",
	$password ? "" : "checked";
printf "<input type=radio name=passmode value=1 %s>\n",
	$password ? "checked" : "";
print "<input name=password size=25 value=\"$password\"></td> </tr>\n";

$restricted = &find("restricted", $conf);
printf "<tr> <td><b>$text{'global_restricted'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=restricted value=1 %s> %s\n",
	$restricted ? "checked" : "", $text{'global_extra'};
printf "<input type=radio name=restricted value=0 %s> %s</td> </tr>\n",
	$restricted ? "" : "checked", $text{'global_any'};

if ($lilo_version >= 21.3) {
	$lba = &find("lba32", $conf);
	print "<tr> <td><b>$text{'global_lba'}</b></td> <td>\n";
	printf "<input type=radio name=lba value=1 %s> $text{'yes'}\n",
		$lba ? "checked" : "";
	printf "<input type=radio name=lba value=0 %s> $text{'no'}</td></tr>\n",
		$lba ? "" : "checked";
	}

print "</table></td></tr></table><br>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

