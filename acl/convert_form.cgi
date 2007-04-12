#!/usr/local/bin/perl
# convert_form.cgi
# Display a form for converting unix users to webmin users

require './acl-lib.pl';
$access{'sync'} && $access{'create'} || &error($text{'convert_ecannot'});
&ui_print_header(undef, $text{'convert_title'}, "");

@glist = &list_groups();
if ($access{'gassign'} ne '*') {
	@gcan = split(/\s+/, $access{'gassign'});
	@glist = grep { &indexof($_->{'name'}, @gcan) >= 0 } @glist;
	}
if (!@glist) {
	print "$text{'convert_nogroups'}<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<form action=convert.cgi>\n";
print "$text{'convert_desc'}<p>\n";
print "<input type=radio name=conv value=0 checked> $text{'convert_0'}<br>\n";
print "<input type=radio name=conv value=1> $text{'convert_1'} ",
      "<input name=users size=40> ",&user_chooser_button("users",1),"<br>\n";
print "<input type=radio name=conv value=2> $text{'convert_2'} ",
      "<input name=nusers size=40> ",&user_chooser_button("nusers",1),"<br>\n";
print "<input type=radio name=conv value=3> $text{'convert_3'} ",
      &unix_group_input("group"),"<br>\n";
print "<input type=radio name=conv value=4> $text{'convert_4'} ",
      "<input name=min size=6> - <input name=max size=6><p>\n";

print "$text{'convert_group'} <select name=wgroup>\n";
foreach $g (@glist) {
	print "<option>$g->{'name'}\n";
	}
print "</select><br>\n";
print "<input type=checkbox name=sync value=1> $text{'convert_sync'}<br>\n";
print "<input type=submit value='$text{'convert_ok'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

