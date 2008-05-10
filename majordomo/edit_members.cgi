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

if ($access{'edit'}) {
	print "$text{'members_desc'}<br>\n";
	}
else {
	print "$text{'members_rodesc'}<br>\n";
	}
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
	print "<p>\n";
	}
else {
	print "<br><input type=submit value=\"$text{'save'}\" name=update>\n";
	print &ui_hr();

	print "<table>\n";
	print "<tr> <td><b>$text{'members_sub'}</b></td>\n";
	print "<td><input name=addr_a size=40> ",
	      "<input type=submit name=add ",
	      "value=\"$text{'members_add'}\"></td> </tr>\n";

	print "<tr> <td><b>$text{'members_unsub'}</b></td>\n";
	print "<td><input name=addr_r size=40> ",
	      "<input type=submit name=remove ",
	      "value=\"$text{'members_rem'}\"></td> </tr>\n";
	print "</table></form>\n";

	print &ui_hr();
	print "<form action=save_auto.cgi>\n";
	print "<input type=hidden name=name value='$in{'name'}'>\n";
	print "<table>\n";
	$sync = $config{"sync_$in{'name'}"};
	print "<tr> <td><b>$text{'members_sync'}</b></td> <td>\n";
	printf "<input type=radio name=sync value=1 %s> %s\n",
		$sync ? "checked" : "", $text{'yes'};
	printf "<input type=radio name=sync value=0 %s> %s</td> </tr>\n",
		$sync ? "" : "checked", $text{'no'};

	$shost = $config{"shost_$in{'name'}"};
	print "<tr><td><b>$text{'members_dom'}</b></td>\n";
	print "<td><input name=shost size=40 value='$shost'>\n";
	print "<input type=submit value=\"$text{'save'}\"></td> </tr>\n";

	print "</table></form>\n";
	}

&ui_print_footer("edit_list.cgi?name=$in{'name'}", $text{'edit_return'});

