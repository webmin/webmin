#!/usr/local/bin/perl
# edit_mods.cgi
# Form for installing and removing usermin modules

require './usermin-lib.pl';
$access{'umods'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'mods_title'}, "");

# Display installation form
print "$text{'mods_desc1'}<p>";

print "<form action=install_mod.cgi enctype=multipart/form-data method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'mods_install'}</b></td> </tr>\n";
print "<tr $cb> <td nowrap>\n";
print "<input type=radio name=source value=0 checked> $text{'mods_local'}\n";
print "<input name=file size=40>\n";
print &file_chooser_button("file", 0),"<br>\n";
print "<input type=radio name=source value=1> $text{'mods_uploaded'}\n";
print "<input name=upload type=file size=30><br>\n";
print "<input type=radio name=source value=2> $text{'mods_ftp'}\n";
print "<input name=url size=40><br>\n";
print "&nbsp;" x 5;
print "<input type=checkbox name=nodeps value=1> $text{'mods_nodeps'}<br>\n";
print "</td></tr></table>\n";
print "<input type=submit value=\"$text{'mods_installok'}\">\n";
print "</form><hr>\n";

# Display cloning form
@mlist = &list_modules();
print "$text{'mods_desc2'}<p>";

print "<form action=clone_mod.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'mods_clone'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td nowrap><b>$text{'mods_cname'}</b></td>\n";
print "<td><select name=mod>\n";
foreach $m (@mlist) {
	if (!$m->{'clone'}) {
		printf "<option value='%s'>%s</option>\n",
			$m->{'dir'}, $m->{'desc'};
		}
	}
closedir(DIR);
print "</select></td> </tr>\n";
print "<tr> <td nowrap><b>$text{'mods_cnew'}</b></td>\n";
print "<td><input name=desc size=30></td> </tr>\n";
print "<tr> <td nowrap><b>$text{'mods_ccat'}</b></td>\n";
print "<td><select name=cat>\n";
print "<option value=* selected>$text{'mods_csame'}</option>\n";
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/lang/en", \%utext);
&read_file("$miniserv{'root'}/ulang/en", \%utext);
foreach $t (keys %utext) {
	if ($t =~ /^category_(.*)/) {
		$cats{$1} = $utext{$t};
		}
	}
&read_file("$config{'usermin_dir'}/webmin.catnames", \%catnames);
foreach $t (keys %catnames) {
	$cats{$t} = $catnames{$t};
	}
foreach $c (sort { $cats{$a} cmp $cats{$b} } keys %cats) {
	print "<option value=$c>$cats{$c}</option>\n";
	}
print "</select></td> </tr>\n";
print "</table></td></tr> </table>\n";
print "<input type=submit value=\"$text{'mods_cloneok'}\">\n";
print "</form><hr>\n";

# Display deletion form
print "$text{'mods_desc3'}<p>\n";

print "<form action=delete_mod.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td valign=top><b>$text{'mods_delete'}</b></td> </tr>\n";
print "<tr> <td $cb><select multiple width=300 name=mod size=10>\n";
$version = &get_usermin_version();
&get_usermin_miniserv_config(\%miniserv);
$home = $miniserv{'root'} eq '/usr/local/useradmin';
foreach $m (@mlist) {
	if (&check_usermin_os_support($m)) {
		local @st = stat("$miniserv{'root'}/$m->{'dir'}");
		local @tm = localtime($st[9]);
		local $vstr = $m->{'version'} == $version ? "" :
			      $m->{'version'} ? "(v. $m->{'version'})" :
			      $home ? "" :
			      sprintf "(%d/%d/%d)",
				      $tm[3], $tm[4]+1, $tm[5]+1900;
		printf "<option value='%s'>%s %s</option>\n",
			$m->{'dir'}, $m->{'desc'}, $vstr;
		}
	}
print "</select></td> </tr></table>\n";
print "<input type=submit value=\"$text{'mods_deleteok'}\">\n";
print "</form>\n";

# Display export form
print &ui_hr();
print "$text{'mods_desc4'}<p>\n";

print &ui_form_start("export_mod.cgi/module.wbm.gz");
print &ui_table_start($text{'mods_header4'}, undef, 2);

print &ui_table_row($text{'mods_exportmods'},
   	  &ui_select("mod", undef,
		[ map { [ $_->{'dir'}, $_->{'desc'} ] } @mlist ], 10, 1));

print &ui_table_row($text{'mods_exportto'},
	  &ui_radio("to", 0,
		[ [ 0, $text{'mods_exportshow'}."<br>" ],
		  [ 1, &text('mods_exportfile',
			     &ui_textbox("file", undef, 40)) ] ]));

print &ui_table_end();
print &ui_form_end([ [ "ok", $text{'mods_exportok'} ] ]);

&ui_print_footer("", $text{'index_return'});

