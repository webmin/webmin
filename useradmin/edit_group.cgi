#!/usr/local/bin/perl
# edit_group.cgi
# Display a form for editing or creating a group

require './user-lib.pl';
&ReadParse();
$n = $in{'num'};
%access = &get_module_acl();
if ($n eq "") {
	$access{'gcreate'}==1 || &error($text{'gedit_ecreate'});
	&ui_print_header(undef, $text{'gedit_title2'}, "", "create_group");
	}
else {
	@glist = &list_groups();
	%group = %{$glist[$n]};
	&can_edit_group(\%access, \%group) ||
		&error($text{'gedit_eedit'});
	&ui_print_header(undef, $text{'gedit_title'}, "", "edit_group");
	}

&build_group_used(\%gused);

print "<form action=\"save_group.cgi\" method=post>\n";
if ($n ne "") {
	print "<input type=hidden name=num value=\"$n\">\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gedit_details'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td valign=top>",&hlink("<b>$text{'gedit_group'}</b>","ggroup"),
      "</td>\n";
if ($n eq "") {
	print "<td valign=top><input name=group size=10></td>\n";
	}
else {
	print "<td valign=top><tt>$group{'group'}</tt></td>\n";
	}

print "<td valign=middle>",&hlink("<b>$text{'gedit_gid'}</b>","ggid"),"</td>\n";
if ($n eq "") {
    print "<td>\n";
    $defgid = &allocate_gid(\%gused);

    if ( $access{'calcgid'} && $access{'autogid'} && $access{'usergid'} ) {
        # Show options for calculated, auto-incremented and user entered GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( $access{'calcgid'} && $access{'autogid'} && !$access{'usergid'} ) {
        # Show options for calculated and auto-incremented GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
    }

    if ( $access{'calcgid'} && !$access{'autogid'} && $access{'usergid'} ) {
        # Show options for calculated and user entered GID
        printf "<input type=radio name=gid_def value=2 %s> %s\n",
            $config{'gid_mode'} eq '2' ? "checked" : "",
            $text{'gedit_gid_calc'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( !$access{'calcgid'} && $access{'autogid'} && $access{'usergid'} ) {
        # Show options for auto-incremented and user entered GID
        printf "<input type=radio name=gid_def value=1 %s> %s\n",
            $config{'gid_mode'} eq '1' ? "checked" : "",
            $text{'gedit_gid_def'};
        printf "<input type=radio name=gid_def value=0 %s> %s\n",
            $config{'gid_mode'} eq '0' ? "checked" : "",
	    "<input name=gid size=10 value='$defgid'>";
    }

    if ( $access{'calcgid'} && !$access{'autogid'} && !$access{'usergid'} ) {
        # Hidden field  for calculated GID
	print "<input type=hidden name=gid_def value=2>";
	print "$text{'gedit_gid_calc'} from Berkeley style cksum\n";
    }

    if ( !$access{'calcgid'} && $access{'autogid'} && !$access{'usergid'} ) {
        # Hidden field for auto-incremented GID
	print "<input type=hidden name=gid_def value=1>";
	print "$text{'gedit_gid_calc'}\n";
    }

    if ( !$access{'calcgid'} && !$access{'autogid'} && $access{'usergid'} ) {
        # Show field for user entered GID
	print "<input type=hidden name=gid_def value=0>";
	print "GID: <input name=gid size=10 value='$defgid'>\n";
    }

    if ( !$access{'calcgid'} && !$access{'autogid'} && !$access{'usergid'} ) {
        if ( $config{'gid_mode'} eq '0' ) {
          print "<input type=hidden name=gid_def value=0>";
          print "GID: <input name=gid size=10 value='$defgid'>\n";
        } else {
          print "<input type=hidden name=gid_def value=$config{'gid_mode'}>";
          print "$text{'gedit_gid_def'}\n" if ( $config{'gid_mode'} eq '1' );
          print "$text{'gedit_gid_calc'}\n" if ( $config{'gid_mode'} eq '2' );
        }
    }
    print "</td></tr>\n";
	}
else {
	print "<td valign=top><input name=gid size=10 ",
	      "value=\"$group{'gid'}\"></td>\n";
	}
print "</tr>\n";

print "<tr> <td valign=top>",&hlink("<b>$text{'pass'}</b>","gpasswd"),"</td>\n";
printf "<td valign=top><input type=radio name=passmode value=0 %s> $text{'none2'}<br>\n",
	$group{'pass'} eq "" ? "checked" : "";
printf "<input type=radio name=passmode value=1 %s> $text{'encrypted'}\n",
	$group{'pass'} eq "" ? "" : "checked";
print "<input name=encpass size=13 value=\"$group{'pass'}\"><br>\n";
print "<input type=radio name=passmode value=2 %s> $text{'clear'}\n";
print "<input name=pass size=15></td>\n";

# Member chooser
local $w = 500;
local $h = 200;
if ($gconfig{'db_sizeusers'}) {
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
print "<td valign=top>",&hlink("<b>$text{'gedit_members'}</b>","gmembers"),
      "</td>\n";
print "<td><table><tr><td><textarea wrap=auto name=members rows=5 cols=10>",
	join("\n", split(/,/ , $group{'members'})),"</textarea></td>\n";
print "<td valign=top><input type=button onClick='ifield = document.forms[0].members; chooser = window.open(\"my_user_chooser.cgi?multi=1&user=\"+escape(ifield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbars=yes,width=$w,height=$h\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\"></td></tr></table></td> </tr>\n";
print "</table></td></tr></table><p>\n";

if ($n ne "") {
	if ($access{'chgid'} == 1 || $access{'mothers'} == 1) {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'onsave'}</b></td> </tr>\n";
		print "<tr $cb> <td><table>\n";

		if ($access{'chgid'} == 1) {
			print "<tr> <td>",&hlink($text{'chgid'},"gchgid"),"</td>\n";
			print "<td><input type=radio name=chgid value=0 checked> $text{'no'}</td>\n";
			print "<td><input type=radio name=chgid value=1> $text{'gedit_homedirs'}</td>\n";
			print "<td><input type=radio name=chgid value=2> $text{'gedit_allfiles'}</td> </tr>\n";
			}

		if ($access{'mothers'} == 1) {
			print "<tr> <td>",&hlink($text{'gedit_mothers'},"others"),"</td>\n";
			printf "<td><input type=radio name=others value=1 %s> $text{'yes'}</td>\n",
				$config{'default_other'} ? "checked" : "";
			printf "<td><input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
				$config{'default_other'} ? "" : "checked";
			}

		print "</table></td> </tr></table><p>\n";
		}
	}
else {
	if ($access{'cothers'} == 1) {
		print "<table border width=100%>\n";
		print "<tr $tb> <td><b>$text{'uedit_oncreate'}</b></td> </tr>\n";
		print "<tr $cb> <td><table>\n";

		if ($access{'cothers'} == 1) {
			print "<tr> <td>",&hlink($text{'gedit_cothers'},"others"),"</td>\n";
			printf "<td><input type=radio name=others value=1 %s> $text{'yes'}</td>\n",
				$config{'default_other'} ? "checked" : "";
				
			printf "<td><input type=radio name=others value=0 %s> $text{'no'}</td> </tr>\n",
				$config{'default_other'} ? "" : "checked";
			}

		print "</table></td> </tr></table><p>\n";
		}
	}

if ($n ne "") {
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value=\"$text{'save'}\"></td>\n";

	if ($access{'gdelete'}) {
		print "</form><form action=\"delete_group.cgi\">\n";
		print "<input type=hidden name=num value=\"$n\">\n";
		print "<td align=right><input type=submit value=\"$text{'delete'}\"></td> </tr>\n";
		}
	print "</form></table><p>\n";
	}
else {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

