#!/usr/local/bin/perl
# edit_os.cgi
# Operating system config form

require './usermin-lib.pl';
$access{'os'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'os_title'}, "");

print $text{'os_desc3'},"<br>\n";
print $text{'os_desc2'},"<br>\n";

&get_usermin_config(\%uconfig);
&get_usermin_miniserv_config(\%miniserv);

print "<form action=change_os.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$webmin::text{'os_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# OS according to Usermin
$osfile = "$miniserv{'root'}/os_list.txt";
print "<tr> <td><b>$text{'os_usermin'}</b></td>\n";
print "<td>",&ui_select("type", $uconfig{'real_os_type'},
	[ map { [ $_ ] } sort { $a cmp $b } &unique(map { $_->{'realtype'} }
			 &webmin::list_operating_systems($osfile)) ]),"\n";
print &ui_textbox("version", $uconfig{'real_os_version'}, 10),"</td> </tr>\n";

# Internal OS code
print "<tr> <td><b>$text{'os_iusermin'}</b></td>\n";
print "<td>",&ui_select("itype", $uconfig{'os_type'},
	[ map { [ $_ ] } sort { $a cmp $b } &unique(map { $_->{'type'} }
			 &webmin::list_operating_systems($osfile)) ]),"\n";
print &ui_textbox("iversion", $uconfig{'os_version'}, 10),"</td> </tr>\n";

# Detected OS
%osinfo = &webmin::detect_operating_system($osfile);
print "<tr> <td valign=top><b>$webmin::text{'os_detect'}</b></td> <td>\n";
if ($osinfo{'real_os_type'}) {
	print "$osinfo{'real_os_type'} $osinfo{'real_os_version'}\n";
	if ($osinfo{'os_type'} ne $uconfig{'os_type'} ||
	    $osinfo{'os_version'} ne $uconfig{'os_version'}) {
		print "<br>",&ui_checkbox("update", 1, $text{'os_update'});
		}
	}
else {
	print "<i>$webmin::text{'os_cannot'}</i>\n";
	}
print "</td> </tr>\n";

print "<tr> <td valign=top><b>$webmin::text{'os_path'}</b></td>\n";
print "<td><textarea name=path rows=5 cols=30>",
	join("\n", split(/:/, $uconfig{'path'})),
	"</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$webmin::text{'os_ld_path'}</b></td>\n";
print "<td><textarea name=ld_path rows=3 cols=30>",
	join("\n", split(/:/, $uconfig{'ld_path'})),
	"</textarea></td> </tr>\n";

print "<tr> <td valign=top><b>$webmin::text{'os_envs'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$webmin::text{'os_name'}</b></td> ",
      "<td><b>$webmin::text{'os_value'}</b></td> </tr>\n";
$i = 0;
foreach $e (keys %miniserv) {
	if ($e =~ /^env_(\S+)$/ &&
	    $1 ne "WEBMIN_CONFIG" && $1 ne "WEBMIN_VAR") {
		print "<tr $cb>\n";
		print "<td><input name=name_$i size=20 value='$1'></td>\n";
		print "<td><input name=value_$i size=30 ",
		      "value='$miniserv{$e}'></td>\n";
		print "</tr>\n";
		$i++;
		}
	}
print "<td><input name=name_$i size=20></td>\n";
print "<td><input name=value_$i size=30></td>\n";
print "</table></td></tr>\n";



print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

