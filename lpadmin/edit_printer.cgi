#!/usr/local/bin/perl
# edit_printer.cgi
# Edit or create a printer

require './lpadmin-lib.pl';
&ReadParse();

if ($in{'new'}) {
	$access{'add'} || &error($text{'edit_eadd'});
	&ui_print_header(undef, $text{'edit_add'}, "");
	$prn{'accepting'}++;
	$prn{'enabled'}++;
	$prn{'allow_all'}++;
	$prn{'dev'} = $device_files[0];
	$prn{'ctype'} = [ "postscript" ];
	}
else {
	&can_edit_printer($in{'name'}) || &error($text{'edit_eedit'});
	&ui_print_header(undef, $text{'edit_edit'}, "");
	local $prn = &get_printer($in{'name'});
	$prn || &error(&text('save_egone', $in{'name'}));
	%prn = %$prn;
	}

print "<form action=save_printer.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_conf'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
if ($in{'new'}) {
	print "<td><input name=name size=15></td>\n";
	print "<input type=hidden name=new value=1>\n";
	}
else {
	print "<td>$prn{'name'}</td>\n";
	print "<input type=hidden name=name value=\"$prn{'name'}\">\n";
	}

print "<td align=right><b>$text{'edit_acc'}</b></td>\n";
printf "<td><input type=radio name=accepting value=1 %s> $text{'yes'}\n",
	$prn{'accepting'} ? "checked" : "";
if (&printer_support('why')) {
	printf "<input type=radio name=accepting value=0 %s> %s\n",
		$prn{'accepting'} ? "" : "checked", $text{'edit_why'};
	printf "<input name=accepting_why size=15 value=\"%s\"></td> </tr>\n",
		$prn{'accepting_why'};
	}
else {
	printf "<input type=radio name=accepting value=0 %s> $text{'no'}\n",
		$prn{'accepting'} ? "" : "checked";
	}

if (&printer_support('desc')) {
	print "<tr> <td><b>$text{'edit_desc'}</b></td>\n";
	print "<td><input name=desc size=20 value=\"",
		&html_escape($prn{'desc'}),"\"></td>\n";
	}
else { print "<tr> <td colspan=2></td>\n"; }

print "<td align=right><b>$text{'edit_ena'}</b></td>\n";
printf "<td><input type=radio name=enabled value=1 %s> $text{'yes'}\n",
	$prn{'enabled'} ? "checked" : "";
if (&printer_support('why')) {
	printf "<input type=radio name=enabled value=0 %s> %s\n",
		$prn{'enabled'} ? "" : "checked", $text{'edit_why'};
	printf "<input name=enabled_why size=15 value=\"%s\"></td> </tr>\n",
		$prn{'enabled_why'};
	}
else {
	printf "<input type=radio name=enabled value=0 %s> $text{'no'}\n",
		$prn{'enabled'} ? "" : "checked";
	}

if (&printer_support('allow')) {
	print "<tr> <td valign=top><b>$text{'edit_acl'}</b></td>\n";
	print "<td colspan=3><table><tr><td valign=top>\n";
	printf "<input type=radio name=access value=0 %s> %s<br>\n",
		$prn{'allow_all'} ? "checked" : "", $text{'edit_allow'};
	printf "<input type=radio name=access value=1 %s> %s<br>\n",
		$prn{'deny_all'} ? "checked" : "", $text{'edit_deny'};
	printf "<input type=radio name=access value=2 %s> %s<br>\n",
		$prn{'allow'} ? "checked" : "", $text{'edit_allowu'};
	printf "<input type=radio name=access value=3 %s> %s\n",
		$prn{'deny'} ? "checked" : "", $text{'edit_denyu'};
	print "</td> <td valign=top>\n";
	print "<textarea wrap=auto name=users rows=5 cols=30>",
	      join(" ", (@{$prn{'allow'}}, @{$prn{'deny'}})),
	      "</textarea></td>\n";
	print "<td valign=top>",&user_chooser_button("users",1),"</td>\n";
	print "</tr></table></td> </tr>\n";
	}

if (&printer_support('banner')) {
	print "<tr> <td valign=top><b>$text{'edit_banner'}</b></td> ",
	      "<td valign=top>\n";
	printf "<input type=radio name=prbanner value=1 %s> $text{'yes'}\n",
		$prn{'banner'} ? "checked" : "";
	printf "<input type=radio name=prbanner value=0 %s> %s</td>\n",
		$prn{'banner'} ? "" : "checked", $text{'edit_opt'};
	}
else { print "<tr>\n"; }

if (&printer_support('default')) {
	print "<td align=right><b>$text{'edit_default'}</b></td> <td>\n";
	if (!$prn{'default'}) {
		printf "<input type=radio name=default value=1 %s> $text{'yes'}\n", $prn{'default'} ? "checked" : "";
		printf "<input type=radio name=default value=0 %s> $text{'no'}</td></tr>\n", $prn{'default'} ? "" : "checked";
		}
	else {
		print "<i>$text{'edit_already'}</i> </td> </tr>\n";
		}
	}
elsif (&printer_support('msize')) {
	print "<td align=right><b>$text{'edit_max'}</b></td> <td>\n";
	printf "<input type=radio name=msize_def value=1 %s> %s\n",
		defined($prn{'msize'}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=msize_def value=2 %s> %s\n",
		$prn{'msize'} eq '0' ? "checked" : "", $text{'edit_unlimited'};
	printf "<input type=radio name=msize_def value=0 %s>\n",
		$prn{'msize'} ? "checked" : "";
	printf "<input name=msize size=6 value=\"%s\"> %s</td> </tr>\n",
		$prn{'msize'} ? $prn{'msize'} : "", $text{'blocks'};
	}
else { print "<td colspan=2></tr>\n"; }

if (&printer_support('ctype')) {
	@ctype = @{$prn{'ctype'}};
	print "<tr> <td><b>$text{'edit_dacc'}</b></td> <td colspan=3>\n";
	printf "<input type=checkbox name=ctype_simple %s> %s &nbsp;\n",
		&indexof("simple", @ctype) < 0 ? "" : "checked",
		$text{'edit_dtext'};
	printf "<input type=checkbox name=ctype_postscript %s> %s &nbsp;\n",
		&indexof("postscript", @ctype) < 0 ? "" : "checked",
		$text{'edit_dpost'};
	@ctypeo = grep { !/^(simple|postscript)$/ } @ctype;
	printf "<input type=checkbox name=ctype_other %s> %s\n",
		@ctypeo ? "checked" : "", $text{'edit_dother'};
	printf "<input name=ctype_olist size=20 value=\"%s\">\n",
		join(' ', @ctypeo);
	print "</td> </tr>\n";
	}

if (&printer_support('alias')) {
	@alias = @{$prn{'alias'}};
	print "<tr> <td><b>$text{'edit_alt'}</b></td> <td colspan=3>\n";
	printf "<input name=alias size=40 value=\"%s\"></td> </tr>\n",
		join(' ', @alias);
	}

print "</table></td></tr></table><p>\n";

if ($in{'new'} || &printer_support('editdest')) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_dest'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	$isdev = &indexof($prn{'dev'}, @device_files) >= 0;
	if (!$webmin_windows_driver) {
		$wdrv = &is_webmin_windows_driver($prn{'iface'}, \%prn);
		$webmin++ if ($wdrv);
		}
	$wdrv = &is_windows_driver($prn{'iface'}, \%prn) if (!$wdrv);
	$hdrv = &is_hpnp_driver($prn{'iface'}, \%prn);
	if ($wdrv) { $prn{'iface'} = $wdrv->{'program'}; }
	elsif ($hdrv) { $prn{'iface'} = $hdrv->{'program'}; }

	printf "<tr> <td><input type=radio name=dest value=0 %s> %s</td>\n",
		$prn{'dev'} && $isdev && !$wdrv && !$hdrv ? "checked" : "",
		$text{'edit_dev'};
	print "<td><select name=dev>\n";
	for($i=0; $i<@device_files; $i++) {
		$d = $device_files[$i];
		printf "<option value=\"$d\" %s>$device_names[$i]\n",
			$d eq $prn{'dev'} ? "selected" : "";
		}
	print "</select></td> </tr>\n";

	printf "<tr> <td><input type=radio name=dest value=1 %s> %s</td>\n",
		$prn{'dev'} && !$isdev && !$wdrv && !$hdrv ? "checked" : "",
		$text{'edit_file'};
	printf "<td><input name=file size=25 value=\"%s\"></td> </tr>\n",
		$isdev || $wdrv || $hdrv ? "" : $prn{'dev'};

	printf "<tr> <td><input type=radio name=dest value=2 %s>\n",
		$prn{'rhost'} ? "checked" : "";
	print "$text{'edit_remote'}</td>\n";
	print "<td><input name=rhost size=25 value=\"$prn{'rhost'}\"></td>\n";
	print "<td>$text{'edit_rqueue'} ",
	      "<input name=rqueue size=15 value=\"$prn{'rqueue'}\">\n";
	if (defined(&remote_printer_types)) {
		@rtypes = &remote_printer_types();
		}
	elsif (&printer_support('sysv')) {
		@rtypes = ( [ 'bsd', 'BSD' ], [ 's5', 'SysV' ] );
		}
	elsif (&printer_support('ipp')) {
		@rtypes = ( [ 'bsd', 'BSD' ], [ 'ipp', 'IPP' ] );
		}
	if (@rtypes) {
		print "$text{'edit_type'} <select name=rtype>\n";
		foreach $t (@rtypes) {
			printf "<option value=%s %s>%s\n",
				$t->[0],
				$prn{'rtype'} eq $t->[0] ? "selected" : "",
				$t->[1];
			}
		print "</select>\n";
		}
	print "</td> </tr>\n";

	if (&printer_support("direct")) {
		printf "<tr> <td><input type=radio name=dest value=5 %s>\n",
			$prn{'dhost'} ? "checked" : "";
		print "$text{'edit_direct'}</td>\n";
		print "<td><input name=dhost size=25 ",
		      "value=\"$prn{'dhost'}\"></td>\n";
		print "<td>$text{'edit_dport'} ",
		      "<input name=dport size=5 value=\"$prn{'dport'}\">\n";
		print "</td> </tr>\n";
		}

	if (&has_smbclient()) {
		printf "<tr> <td><input type=radio name=dest value=3 %s>\n",
			$wdrv ? "checked" : "";
		printf "$text{'edit_smb'}</td> ".
		      "<td><input name=server size=25 value=\"%s\"></td>\n",
			$wdrv->{'server'};
		printf "<td>$text{'edit_share'} ".
		       "<input name=share size=15 value=\"%s\"></td>\n",
			$wdrv->{'share'};
		print "</tr><tr> <td align=right>$text{'edit_user'}</td>\n";
		printf "<td colspan=2><input name=suser size=10 value='%s'>\n",
			$wdrv->{'user'};
		printf "$text{'edit_pass'} ".
		       "<input type=password name=spass size=10 value='%s'>\n",
			$wdrv->{'pass'};
		printf "$text{'edit_wgroup'} ".
		       "<input name=wgroup size=10 value=\"%s\">\n",
			$wdrv->{'workgroup'};
		print "</td> </tr>\n";
		}

	if (&has_hpnp()) {
		printf "<tr> <td><input type=radio name=dest value=4 %s>\n",
			$hdrv ? "checked" : "";
		print "$text{'edit_hpnp'}</td>\n";
		printf "<td><input name=hpnp size=25 value=\"%s\"></td>\n",
			$hdrv->{'server'};
		printf "<td>$text{'edit_port'} ".
		       "<input name=port size=15 value=\"%s\"></td> </tr>\n",
			$hdrv->{'port'};
		}

	print "<tr> <td>&nbsp;&nbsp;&nbsp;&nbsp;",
	      "<input type=checkbox name=check value=1> ",
	      "$text{'edit_check'}</td> </tr>\n";

	print "</table></td></tr></table><p>\n";

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_driver'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";
	if (!$webmin_print_driver) {
		$drv = &is_webmin_driver($prn{'iface'}, \%prn);
		}
	if ($drv->{'mode'} != 0 && $drv->{'mode'} != 2 || $webmin) {
		$webmin++;
		$after = &webmin_driver_input(\%prn, $drv);
		}
	else {
		$drv = &is_driver($prn{'iface'}, \%prn);
		$after = &driver_input(\%prn, $drv);
		}
	print "</table></td></tr></table><p>\n";
	}
print "<input type=hidden name=webmin value=\"$webmin\">\n";

if ($in{'new'}) {
	print "<input type=submit value=\"$text{'create'}\"></form><p>\n";
	}
else {
	print "<table width=100%>\n";
	print "<tr> <td><input type=submit value=\"$text{'save'}\"></td>\n";
	if ($access{'delete'}) {
		print "</form><form action=\"delete_printer.cgi\">\n";
		print "<input type=hidden name=name value=\"$in{'name'}\">\n";
		print "<td align=right><input type=submit ",
		      "value=\"$text{'delete'}\"></td> </tr>\n";
		}
	print "</form></table>\n";
	}
print $after;

&ui_print_footer("", $text{'index_return'});

