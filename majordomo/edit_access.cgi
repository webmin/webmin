#!/usr/local/bin/perl
# edit_access.cgi
# Edit access control options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'access_title'}, "");

print "<form action=save_access.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'access_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print &choice_input("get_access", $text{'access_get'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print &choice_input("index_access", $text{'access_index'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print "</tr>\n";

print "<tr>\n";
print &choice_input("info_access", $text{'access_info'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print &choice_input("intro_access", $text{'access_intro'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print "</tr>\n";

print "<tr>\n";
print &choice_input("which_access", $text{'access_which'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print &choice_input("who_access", $text{'access_who'}, $conf,
		    "open",$text{'access_open'}, "list",$text{'access_list'},
		    "closed",$text{'access_closed'});
print "</tr>\n";

$adv = &find_value("advertise", $conf);
$noadv = &find_value("noadvertise", $conf);
print "<tr>\n";
print "<td valign=top><b>$text{'access_adv'}</b></td> <td valign=top>\n";
printf "<input type=radio name=adv_mode value=0 %s> $text{'access_adv0'}<br>\n",
	$adv !~ /\S/ && $noadv !~ /\S/ ? "checked" : "";
printf "<input type=radio name=adv_mode value=1 %s> $text{'access_adv1'}<br>\n",
	$adv =~ /\S/ ? "checked" : "";
printf "<input type=radio name=adv_mode value=2 %s> $text{'access_adv2'}<br>\n",
	$noadv =~ /\S/ ? "checked" : "";
print "</td> <td valign=top colspan=2>\n";
printf "<textarea rows=4 cols=40 name=adv>%s</textarea></td> </tr>\n",
	$adv =~ /\S/ ? $adv : $noadv =~ /\S/ ? $noadv : "";

$res = &find_value("restrict_post", $conf);
$ldir = &perl_var_replace(&find_value("listdir", &get_config()),
			  &get_config());
$reslist = $res eq $in{'name'} || $res eq "$ldir/$in{'name'}";
print "<tr> <td><b>$text{'access_res'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=res_mode value=0 %s> $text{'access_res0'}\n",
	$res ? "" : "checked";
printf "<input type=radio name=res_mode value=1 %s> $text{'access_res1'}\n",
	$reslist ? "checked" : "";
printf "<input type=radio name=res_mode value=2 %s> $text{'access_res2'}\n",
	$res && !$reslist ? "checked" : "";
printf "<input name=res size=35 value=\"%s\">%s</td> </tr>\n",
	$res && !$reslist ? $res : "", &file_chooser_button("res", 0);

print "<tr>\n";
print &multi_input("taboo_body", $text{'access_tbody'}, $conf);
print "</tr>\n";

print "<tr>\n";
print &multi_input("taboo_headers", $text{'access_theader'}, $conf);
print "</tr>\n";

print "<tr> <td colspan=4>$text{'access_taboo'}</td> </tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

