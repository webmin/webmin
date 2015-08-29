#!/usr/local/bin/perl
# edit_aserv.cgi
# Edit <Anonymous> section details

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
$desc = $in{'virt'} eq '' ? $text{'anon_header2'} :
	      &text('anon_header1', $v->{'value'});
if (!$in{'init'}) {
	$anon = &find_directive_struct("Anonymous", $conf);
	&ui_print_header($desc, $text{'aserv_title'}, "",
		undef, undef, undef, undef, &restart_button());
	}
else {
	&ui_print_header($desc, $text{'aserv_create'}, "",
		undef, undef, undef, undef, &restart_button());
	}

print $text{'aserv_desc'},"<br>\n" if ($in{'init'});

$user = &find_directive("User", $anon->{'members'});
$user ||= "ftp" if ($in{'init'});
$group = &find_directive("Group", $anon->{'members'});
$group ||= "ftp" if ($in{'init'});

print "<form action=save_aserv.cgi>\n";
print "<input type=hidden name=virt value='$in{'virt'}'>\n";
print "<input type=hidden name=init value='$in{'init'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'aserv_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'aserv_root'}</b></td>\n";
printf "<td><input name=root size=40 value='%s'> %s</td> </tr>\n",
	$anon->{'value'}, &file_chooser_button("root", 1);

print "<tr> <td><b>$text{'aserv_user'}</b></td>\n";
print "<td>",&opt_input($user, "User", $text{'default'}, 13),
      "</td> </tr>\n";

print "<tr> <td><b>$text{'aserv_group'}</b></td>\n";
print "<td>",&opt_input($group, "Group", $text{'default'}, 13),
      "</td> </tr>\n";

print "<tr> <td colspan=2>\n";
if ($in{'init'}) {
	print "<input type=submit value=\"$text{'create'}\">\n";
	}
else {
	print "<input type=submit value=\"$text{'save'}\">\n";
	}
print "</td> </tr>\n";

print "</table> </td></tr></table><p>\n";
print "</form>\n";

if ($in{'init'}) {
	&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}

