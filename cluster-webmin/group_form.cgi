#!/usr/local/bin/perl
# group_form.cgi
# Display a form for adding a new webmin group to all servers

require './cluster-webmin-lib.pl';
&ui_print_header(undef, $text{'user_title1'}, "");

@hosts = &list_webmin_hosts();
@mods = &all_modules(\@hosts);
@wgroups = &all_groups(\@hosts);

print "<form action=create_group.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'group_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'group_name'}</b></td>\n";
print "<td><input name=name size=15></td>\n";

print "<td><b>$text{'user_group'}</b></td>\n";
print "<td><select name=group>\n";
print "<option selected value=''>$text{'user_nogroup'}</option>\n";
foreach $g (@wgroups) {
	print "<option>$g->{'name'}</option>\n";
	}
print "</select></td> </tr>\n";

$mp = int((scalar(@mods)+2)/3);
print "<tr> <td valign=top><b>$text{'user_mods'}</b><br>",
      "$text{'user_groupmods'}</td> <td colspan=3 nowrap>\n";
print "<select name=mods1 size=$mp multiple>\n";
for($i=0; $i<$mp; $i++) {
	print "<option value=$mods[$i]->{'dir'}>$mods[$i]->{'desc'}</option>\n";
	}
print "</select>\n";
print "<select name=mods2 size=$mp multiple>\n";
for($i=$mp; $i<$mp*2; $i++) {
	print "<option value=$mods[$i]->{'dir'}>$mods[$i]->{'desc'}</option>\n";
	}
print "</select>\n";
print "<select name=mods3 size=$mp multiple>\n";
for($i=$mp*2; $i<@mods; $i++) {
	print "<option value=$mods[$i]->{'dir'}>$mods[$i]->{'desc'}</option>\n";
	}
print "</select>\n";

print "<br>\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = true; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = true; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = true; } return false'>$text{'user_sall'}</a>&nbsp;\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = false; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = false; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = false; } return false'>$text{'user_snone'}</a>&nbsp;\n";
print "<a href='' onClick='for(i=0; i<document.forms[0].mods1.options.length; i++) { document.forms[0].mods1.options[i].selected = !document.forms[0].mods1.options[i].selected; } for(i=0; i<document.forms[0].mods2.options.length; i++) { document.forms[0].mods2.options[i].selected = !document.forms[0].mods2.options[i].selected; } for(i=0; i<document.forms[0].mods3.options.length; i++) { document.forms[0].mods3.options[i].selected = !document.forms[0].mods3.options[i].selected; } return false'>$text{'user_sinvert'}</a><br>\n";

print "</td> </tr>\n";

&create_on_input($text{'group_servers'}, 0, 1);

print "</table></td></tr></table><br>\n";
print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

