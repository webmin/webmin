#!/usr/local/bin/perl
# edit_subs.cgi
# Edit subscription options

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$conf = &get_list_config($list->{'config'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'subs_title'}, "");

print "<form action=save_subs.cgi>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'subs_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

$pol = &find_value("subscribe_policy", $conf);
if ($pol =~ /(\S+)\+confirm/) { $pol = $1; $confirm = 1; }
print "<tr> <td><b>$text{'subs_sub'}</b></td> <td colspan=3 nowrap>\n";
printf "<input name=subscribe_policy type=radio value=open %s> %s\n",
	$pol eq "open" ? "checked" : "", $text{'subs_sopen'};
printf "<input name=subscribe_policy type=radio value=auto %s> %s\n",
	$pol eq "auto" ? "checked" : "", $text{'subs_sauto'};
printf "<input name=subscribe_policy type=radio value=closed %s> %s\n",
	$pol eq "closed" ? "checked" : "", $text{'subs_closed'};
print "</td> </tr>\n";

$upol = &find_value("unsubscribe_policy", $conf);
print "<tr> <td><b>$text{'subs_unsub'}</b></td> <td colspan=3 nowrap>\n";
printf "<input name=unsubscribe_policy type=radio value=open %s> %s\n",
	$upol eq "open" ? "checked" : "", $text{'subs_uopen'};
printf "<input name=unsubscribe_policy type=radio value=auto %s> %s\n",
	$upol eq "auto" ? "checked" : "", $text{'subs_uauto'};
printf "<input name=unsubscribe_policy type=radio value=closed %s> %s\n",
	$upol eq "closed" ? "checked" : "", $text{'subs_closed'};
print "</td> </tr>\n";

print "<tr> <td><b>$text{'subs_confirm'}</b></td> <td>\n";
printf "<input name=subscribe_policy_c type=radio value='+confirm' %s> %s\n",
	$confirm ? "checked" : "", $text{'yes'};
printf "<input name=subscribe_policy_c type=radio value='' %s> %s</td>\n",
	$confirm ? "" : "checked", $text{'no'};
print &choice_input("welcome", $text{'subs_welcome'}, $conf,
		    "yes", $text{'yes'}, "no", $text{'no'});
print "</tr>\n";

print "<tr>\n";
print &choice_input("strip", $text{'subs_strip'}, $conf,
		    "yes", $text{'yes'}, "no", $text{'no'});
print &choice_input("announcements", $text{'subs_announcements'},
		    $conf, "yes", $text{'yes'}, "no", $text{'no'});
print "</tr>\n";

print "<tr>\n";
print &choice_input("administrivia", $text{'subs_administrivia'},
		    $conf, "yes", $text{'yes'}, "no", $text{'no'});
print &opt_input("admin_passwd", $text{'subs_passwd'}, $conf,
		 $text{'default'}, 10);
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";
print "<tr>\n";
print &choice_input("moderate", $text{'subs_moderate'}, $conf,
		    "yes", $text{'yes'}, "no", $text{'no'});
print &opt_input("moderator", $text{'subs_moderator'}, $conf,
		 $text{'subs_maint'}, 20);
print "</tr>\n";

print "<tr>\n";
print &opt_input("approve_passwd", $text{'subs_mpasswd'}, $conf,
		 $text{'default'}, 10);
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";
$aliases_files = &get_aliases_file();
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	$owner = $a->{'value'}
		if (lc($a->{'name'}) eq lc("$in{'name'}-owner") ||
		    lc($a->{'name'}) eq lc("owner-$in{'name'}"));
	$approval = $a->{'value'}
		if (lc($a->{'name'}) eq lc("$in{'name'}-approval"));
	}
print "<tr> <td><b>$text{'subs_owner'}</b></td>\n";
print "<td><input name=owner size=20 value=".&get_alias_owner($owner)."></td>\n";

print "<td><b>$text{'subs_approval'}</b></td>\n";
print "<td><input name=approval size=20 value='$approval'></td> </tr>\n";

print "</table></td></tr></table>\n";
print &ui_submit($text{'save'}),"</form>\n";

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

