#!/usr/local/bin/perl
# user_form.cgi
# Display a form for adding a new webmin user to all servers

require './cluster-webmin-lib.pl';
&ui_print_header(undef, $text{'user_title1'}, "");

@hosts = &list_webmin_hosts();
@mods = &all_modules(\@hosts);
@themes = &all_themes(\@hosts);
@wgroups = &all_groups(\@hosts);

print "<form action=create_user.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'user_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'user_name'}</b></td>\n";
print "<td><input name=name size=15></td>\n";

print "<td><b>$text{'user_group'}</b></td>\n";
print "<td><select name=group>\n";
print "<option selected value=''>$text{'user_nogroup'}</option>\n";
foreach $g (@wgroups) {
	print "<option>$g->{'name'}</option>\n";
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'user_pass'}</b></td> <td colspan=3>\n";
print "<select name=pass_def>\n";
print "<option value=0 selected>$text{'user_set'} ..</option>\n";
print "<option value=3>$text{'user_unix'}</option>\n";
print "<option value=4>$text{'user_lock'}</option>\n";
print "<option value=5>$text{'user_extauth'}</option>\n";
print "</select><input type=password name=pass size=25></td> </tr>\n";

print "<tr> <td><b>$text{'user_lang'}</b></td> <td>\n";
print "<select name=lang>\n";
print "<option value='' selected>$text{'user_default'}</option>\n";
foreach $l (&list_languages()) {
	printf "<option value=%s>%s (%s)</option>\n",
		$l->{'lang'},
		$l->{'desc'}, uc($l->{'lang'});
	}
print "</select></td>\n";

print "<td><b>$text{'user_theme'}</b></td> <td>\n";
print "<select name=theme>\n";
print "<option value=webmin selected>$text{'user_default'}</option>\n";
foreach $t ( { 'desc' => $text{'user_themedef'} }, @themes) {
	printf "<option value='%s'>%s</option>\n", $t->{'dir'}, $t->{'desc'};
	}
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'user_ips'}</b></td>\n";
print "<td colspan=3><table><tr>\n";
print "<td nowrap><input name=ipmode type=radio value=0 checked> ",
      "$text{'user_allips'}<br>\n";
print "<input name=ipmode type=radio value=1> $text{'user_allow'}<br>\n";
print "<input name=ipmode type=radio value=2> $text{'user_deny'}</td>\n";
print "<td><textarea name=ips rows=4 cols=30></textarea></td>\n";
print "</td> </tr></table> </tr>\n";

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

&create_on_input($text{'user_servers'}, 0, 1);

print "</table></td></tr></table><br>\n";
print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

