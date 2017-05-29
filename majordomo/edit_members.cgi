#!/usr/local/bin/perl
# edit_members.cgi
# Display a form for editing the members of some list

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) || &error($text{'edit_ecannot'});
$list = &get_list($in{'name'}, &get_config());
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'members_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>";
if ($access{'edit'}) {
	print "$text{'members_desc'}\n";
	}
else {
	print "$text{'members_rodesc'}\n";
	}
print "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
print "<form action=save_members.cgi method=post enctype=multipart/form-data>\n";
print "<input type=hidden name=name value='$in{'name'}'>\n";
print "<textarea rows=15 cols=60 name=members>\n";
open(MEMS, $list->{'members'});
while(<MEMS>) {
	print &html_escape($_);
	}
close(MEMS);
print "</textarea>\n";
if (!$access{'edit'}) {
	print "<p></form></table>\n";
	}
else {
	print "<br> <input class=\"btn btn-success\" type=submit value=\"$text{'save'}\" name=update>\n";

	print "<table width=100%>\n";
	print "<tr> <td><b>$text{'members_sub'}</b></td>\n";
	print "<td><input name=addr_a size=40> ",
	      &ui_submit($text{'members_add'}, "add"),"</td> </tr>\n";

	print "<tr> <td><b>$text{'members_unsub'}</b></td>\n";
	print "<td width=500><input name=addr_r size=40> ",
	      &ui_submit($text{'delete'}, "remove"), "</td> </tr>\n";
	print "</table></form></table>\n";

	print "<form action=save_auto.cgi>\n";
	print "<input type=hidden name=name value='$in{'name'}'>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><small><strong>$text{'misc_header'}<strong></small></td> </tr>\n";
	print "<tr $cba><table width=100%>\n";
	$sync = $config{"sync_$in{'name'}"};
	print "<tr> <td><b>$text{'members_sync'}</b></td> <td>\n";
	printf "<input type=radio name=sync value=1 %s> %s\n",
		$sync ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=sync value=0 %s> %s</td> </tr>\n",
		$sync ? "" : "checked", $text{'no'};

	$shost = $config{"shost_$in{'name'}"};
	print "<tr><td><b>$text{'members_dom'}</b></td>\n";
	print "<td width=500><input name=shost size=40 value='$shost'>\n";
	print &ui_submit($text{'save'}),"</td> </tr>\n";
	print "</table></td></tr></table></form>\n";
	}

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});
