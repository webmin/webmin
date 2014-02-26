#!/usr/local/bin/perl
# edit_profile.cgi
# Edit or create a burn profile

require './burner-lib.pl';
&ReadParse();

if ($in{'type'}) {
	$access{'create'} || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'create_title'}, "");
	$profile = { 'type' => $in{'type'} };
	}
else {
	$profile = &get_profile($in{'id'});
	&can_use_profile($profile) || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'edit_title'}, "");
	}

if ($profile->{'type'} == 2 && !&has_command($config{'mkisofs'})) {
	print "<p>",&text('edit_emkisofs', "<tt>$config{'mkisofs'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{"index_return"});
	exit;
	}
if ($profile->{'type'} == 3 && !&has_command($config{'mpg123'})) {
	print "<p>",&text('edit_empg123', "<tt>$config{'mpg123'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{"index_return"});
	exit;
	}
if ($profile->{'type'} == 4 && !&has_command($config{'cdrdao'})) {
	print "<p>",&text('edit_ecdrdao', "<tt>$config{'cdrdao'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{"index_return"});
	exit;
	}

print "<form action=save_profile.cgi>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";
print "<input type=hidden name=type value='$in{'type'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
print "<td><input name=name size=25 value='$profile->{'name'}'></td>\n";
print "<td colspan=2></td> </tr>\n";

if ($profile->{'type'} == 1) {
	# Single ISO options
	print "<tr> <td><b>$text{'edit_iso'}</b></td>\n";
	printf "<td colspan=3><input name=iso size=45 value='%s'> %s</td>\n",
		$profile->{'iso'}, &file_chooser_button("iso");
	print "</tr>\n";

	print "<tr> <td><b>$text{'edit_isosize'}</b></td>\n";
	printf "<td><input type=radio name=isosize value=1 %s> %s\n",
		$profile->{'isosize'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=isosize value=0 %s> %s</td> </tr>\n",
		$profile->{'isosize'} ? '' : 'checked', $text{'no'};
	}
elsif ($profile->{'type'} == 2) {
	# Multi-directory options
	print "<tr> <td valign=top><b>$text{'edit_dirs'}</b></td>\n";
	print "<td colspan=3><table width=100% border=1>\n";
	print "<tr $tb> <td><b>$text{'edit_source'}</b></td> ",
	      "<td><b>$text{'edit_dest'}</b></td> </tr>\n";
	for($i=0; $profile->{"source_".($i-4)} || $i < 4; $i++) {
		print "<tr $cb>\n";
		printf "<td><input name=source_%d size=35 value='%s'>%s</td>\n",
			$i, $profile->{"source_$i"}, 
			&file_chooser_button("source_$i");
		printf "<td><input name=dest_%d size=25 value='%s'></td>\n",
			$i, $profile->{"dest_$i"} ? $profile->{"dest_$i"} : "/";
		print "</tr>\n";
		}
	print "</table>\n";

	print "<tr> <td><b>$text{'edit_rock'}</b></td>\n";
	printf "<td colspan=3><input type=radio name=rock value=2 %s> %s\n",
		$profile->{'rock'} == 2 ? 'checked' : '', $text{'edit_rock2'};
	printf "<input type=radio name=rock value=1 %s> %s\n",
		$profile->{'rock'} == 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=rock value=0 %s> %s</td> </tr>\n",
		$profile->{'rock'} == 0 ? 'checked' : '', $text{'no'};

	print "<tr> <td><b>$text{'edit_joliet'}</b></td>\n";
	printf "<td><input type=radio name=joliet value=1 %s> %s\n",
		$profile->{'joliet'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=joliet value=0 %s> %s</td>\n",
		$profile->{'joliet'} ? '' : 'checked', $text{'no'};

	print "<td><b>$text{'edit_long'}</b></td>\n";
	printf "<td><input type=radio name=long value=1 %s> %s\n",
		$profile->{'long'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=long value=0 %s> %s</td> </tr>\n",
		$profile->{'long'} ? '' : 'checked', $text{'no'};

	print "<tr> <td><b>$text{'edit_netatalk'}</b></td>\n";
	printf "<td><input type=radio name=netatalk value=1 %s> %s\n",
		$profile->{'netatalk'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=netatalk value=0 %s> %s</td>\n",
		$profile->{'netatalk'} ? '' : 'checked', $text{'no'};

	print "<td><b>$text{'edit_cap'}</b></td>\n";
	printf "<td><input type=radio name=cap value=1 %s> %s\n",
		$profile->{'cap'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=cap value=0 %s> %s</td> </tr>\n",
		$profile->{'cap'} ? '' : 'checked', $text{'no'};

	print "<tr> <td><b>$text{'edit_trans'}</b></td>\n";
	printf "<td><input type=radio name=trans value=1 %s> %s\n",
		$profile->{'trans'} ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=trans value=0 %s> %s</td>\n",
		$profile->{'trans'} ? '' : 'checked', $text{'no'};

	print "<td><b>$text{'edit_volid'}</b></td>\n";
	printf "<td><input name=volid size=15 value='%s'></td> </tr>\n",
		$profile->{'volid'};
	}
elsif ($profile->{'type'} == 3) {
	# MP3 files or directories of them
	print "<tr> <td valign=top><b>$text{'edit_mp3s'}</b></td>\n";
	print "<td colspan=3>\n";
	for($i=0; $profile->{"source_".($i-4)} || $i < 4; $i++) {
		printf "<input name=source_%d size=50 value='%s'> %s<br>\n",
			$i, $profile->{"source_$i"},
			&file_chooser_button("source_$i");
		}
	print "</td> </tr>\n";
	}
elsif ($profile->{'type'} == 4) {
	# Duplicating a CD
	print "<tr> <td><b>$text{'edit_sdev'}</b></td>\n";
	print "<td colspan=3><select name=sdev>\n";
	foreach $d (&list_cdrecord_devices()) {
		printf "<option value=%s %s>%s (%s)</option>\n",
			$d->{'dev'},
			$d->{'dev'} eq $profile->{'sdev'} ? 'selected' : '',
			$d->{'name'}, $d->{'type'};
		$found++ if ($d->{'dev'} eq $profile->{'sdev'});
		}
	printf "<option value='' %s>%s</option>\n",
		!$found && $profile->{'sdev'} ? "selected" : "",
		$text{'edit_other'};
	print "</select>\n";
	printf "<input name=other size=30 value='%s'></td> </tr>\n",
		$found ? "" : $profile->{'sdev'};

	print "<tr> <td><b>$text{'edit_srcdrv'}</b></td>\n";
	print "<td><select name=srcdrv>\n";
	printf "<option value='' %s>%s</option>\n",
		$profile->{'srcdrv'} ? "" : "selected", $text{'default'};
	foreach $d (@cdr_drivers) {
		printf "<option %s>%s</option>\n",
			$profile->{'srcdrv'} eq $d ? "selected" : "", $d;
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'edit_dstdrv'}</b></td>\n";
	print "<td><select name=dstdrv>\n";
	printf "<option value='' %s>%s</option>\n",
		$profile->{'dstdrv'} ? "" : "selected", $text{'default'};
	foreach $d (@cdr_drivers) {
		printf "<option %s>%s</option>\n",
			$profile->{'dstdrv'} eq $d ? "selected" : "", $d;
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'edit_fly'}</b></td>\n";
	printf "<td><input type=radio name=fly value=1 %s> %s\n",
		$profile->{'fly'} ? "checked" : "", $text{'edit_fly1'};
	printf "<input type=radio name=fly value=0 %s> %s</td> </tr>\n",
		$profile->{'fly'} ? "" : "checked", $text{'edit_fly0'};
	}

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";

if ($access{'edit'}) {
	# Show save, burn, test and delete buttons
	print "<td width=25%><input type=submit value='$text{'save'}'></td>\n";
	if ($profile->{'type'} == 4) {
		print "<td width=50% colspan=2 align=center>",
		      "<input type=submit name=burn ",
		      "value='$text{'edit_burn'}'></td>\n";
		}
	else {
		print "<td width=25% align=center>",
		      "<input type=submit name=burn ",
		      "value='$text{'edit_burn'}'></td>\n";
		print "<td width=25% align=center>",
		      "<input type=submit name=test ",
		      "value='$text{'edit_test'}'></td>\n";
		}
	if ($profile->{'id'}) {
		print "<td width=25% align=right>",
		      "<input type=submit name=delete ",
		      "value='$text{'delete'}'></td>\n";
		}
	else {
		print "<td width=25%></td>\n";
		}
	print "</tr>\n";
	print "<tr> <td></td> <td width=50% align=center colspan=2>\n";
	print "<input type=checkbox name=ask value=1 checked> ",
	      "$text{'edit_ask'}\n";
	print "</td> <td></td>\n";
	}
else {
	# Show only burn and test burn buttons
	if ($profile->{'type'} == 4) {
		print "<td width=50% colspan=2 align=left>",
		      "<input type=submit name=burn ",
		      "value='$text{'edit_burn2'}'></td>\n";
		}
	else {
		print "<td width=50% align=left>",
		      "<input type=submit name=burn ",
		      "value='$text{'edit_burn2'}'></td>\n";
		print "<td width=50% align=right>",
		      "<input type=submit name=test ",
		      "value='$text{'edit_test2'}'></td>\n";
		}
	print "<input type=hidden name=ask value=1>\n";
	}
print "</tr></table></form>\n";

if (!$access{'edit'}) {
	# Add some javascript to disable form
	print "<script>\n";
	print "l = document.forms[0].elements;\n";
	print "for(i=0; i<l.length; i++) {\n";
	print "    if (l[i].name != \"burn\" && l[i].name != \"test\" &&\n";
	print "        l[i].type != \"hidden\") {\n";
	print "        l[i].disabled = true;\n";
	print "    }\n";
	print "}\n";
	print "</script>\n";
	}

&ui_print_footer("", $text{'index_return'});

