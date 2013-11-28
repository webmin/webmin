#!/usr/local/bin/perl
# group_form.cgi
# Display a form for creating a new group

require './cluster-useradmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'gedit_title2'}, "", "create_group");
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

print "<form action=\"create_group.cgi\" method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top><b>$text{'gedit_group'}</b></td>\n";
print "<td valign=top><input name=group size=10></td>\n";

print "<td valign=top><b>$text{'gedit_gid'}</b></td>\n";
foreach $h (@hosts) {
	foreach $g (@{$h->{'groups'}}) {
		$used{$g->{'gid'}}++;
		}
	}
$newgid = $uconfig{'base_gid'};
while($used{$newgid}) {
	$newgid++;
	}
print "<td valign=top><input name=gid size=10 value='$newgid'></td>\n";
print "</tr>\n";

print "<tr> <td valign=top><b>$text{'pass'}</b></td> <td valign=top>\n";
print "<input type=radio name=passmode value=0 checked> $text{'none2'}<br>\n";
print "<input type=radio name=passmode value=1> $text{'encrypted'}\n";
print "<input name=encpass size=13><br>\n";
print "<input type=radio name=passmode value=2> $text{'clear'}\n";
print "<input name=pass size=15></td>\n";

print "<td valign=top><b>$text{'gedit_members'}</b></td>\n";
print "<td><table><tr><td><textarea wrap=auto name=members rows=5 cols=10>",
      "</textarea></td>\n";
print "<td valign=top><input type=button onClick='ifield = document.forms[0].members; chooser = window.open(\"/useradmin/my_user_chooser.cgi?multi=1&user=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=500,height=200\"); chooser.ifield = ifield' value=\"...\"></td></tr></table></td> </tr>\n";
print "</table></td></tr></table><p>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'gedit_cothers'}</b></td>\n";
print "<td><input type=radio name=others value=1 checked> $text{'yes'}</td>\n";
print "<td><input type=radio name=others value=0> $text{'no'}</td> </tr>\n";

# Show server selection input
&create_on_input($text{'uedit_servers'});

print "</table></td> </tr></table><p>\n";

print "<input type=submit value=\"$text{'create'}\"></form><p>\n";

&ui_print_footer("", $text{'index_return'});

