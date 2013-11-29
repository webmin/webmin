#!/usr/local/bin/perl
# edit_stunnel.cgi
# Edit or create an SSL tunnel run from inetd

require './stunnel-lib.pl';
&ReadParse();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "");
	$st = { 'active' => 1 };
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "");
	@stunnels = &list_stunnels();
	$st = $stunnels[$in{'idx'}];
	}

print "<form action=save_stunnel.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td>\n";
printf "<td><input name=name size=15 value='%s'></td>\n",
	$st->{'name'};

print "<td><b>$text{'edit_port'}</b></td>\n";
printf "<td><input name=port size=6 value='%s'></td> </tr>\n",
	$st->{'port'};

print "<tr> <td><b>$text{'edit_active'}</b></td>\n";
printf "<td><input type=radio name=active value=1 %s> %s\n",
	$st->{'active'} ? "checked" : "", $text{'yes'};
printf "<input type=radio name=active value=0 %s> %s</td>\n",
	$st->{'active'} ? "" : "checked", $text{'no'};

if (!$in{'new'}) {
	print "<td><b>$text{'edit_type'}</b></td>\n";
	print "<td><tt>$st->{'type'}</tt></td>\n";
	}
elsif ($has_inetd && $has_xinetd) {
	print "<td><b>$text{'edit_type'}</b></td>\n";
	print "<td><select name=type>\n";
	print "<option selected>xinetd</option>\n";
	print "<option>inetd</option>\n";
	print "</select></td>\n";
	}
print "</tr>\n";

print "</table></td></tr></table><br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header2'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($in{'new'}) {
	$ptymode = 'l';
	}
elsif (&get_stunnel_version() >= 4) {
	# Parse new-style stunnel configuration file
	if ($st->{'args'} =~ /^(\S+)\s+(\S+)/) {
		$cfile = $2;
		@conf = &get_stunnel_config($cfile);
		($conf) = grep { !$_->{'name'} } @conf;
		if ($cmd = $conf->{'values'}->{'exec'}) {
			$args = $conf->{'values'}->{'execargs'};
			$ptymode = $conf->{'values'}->{'pty'} eq 'yes' ? "L"
								       : "l";
			}
		else {
			$rport = $conf->{'values'}->{'connect'};
			if ($rport =~ /^(\S+):(\d+)/) {
				$rhost = $1;
				$rport = $2;
				}
			}
		$pem = $conf->{'values'}->{'cert'};
		$cmode = $conf->{'values'}->{'client'} =~ /yes/i;
		$tcpw = $conf->{'values'}->{'service'};
		$iface = $conf->{'values'}->{'local'};
		}
	}
else {
	# Parse old-style stunnel parameters
	if ($st->{'args'} =~ s/\s*-([lL])\s+(\S+)\s+--\s+(.*)// ||
	    $st->{'args'} =~ s/\s*-([lL])\s+(\S+)//) {
		$ptymode = $1;
		$cmd = $2;
		$args = $3;
		}
	if ($st->{'args'} =~ s/\s*-r\s+((\S+):)?(\d+)//) {
		$rhost = $2;
		$rport = $3;
		}
	if ($st->{'args'} =~ s/\s*-p\s+(\S+)//) {
		$pem = $1;
		}
	if ($st->{'args'} =~ s/\s*-c//) {
		$cmode = 1;
		}
	if ($st->{'args'} =~ s/\s*-N\s+(\S+)//) {
		$tcpw = $1;
		}
	if ($st->{'args'} =~ s/\s*-I\s+(\S+)//) {
		$iface = $1;
		}
	}

printf "<tr> <td><input type=radio name=mode value=0 %s> %s</td>\n",
	$ptymode eq 'l' ? 'checked' : '', $text{'edit_mode0'};
printf "<td nowrap><b>%s</b> <input name=cmd0 size=15 value='%s'>\n",
	$text{'edit_cmd'}, $ptymode eq 'l' ? $cmd : '';
printf "<b>%s</b> <input name=args0 size=20 value='%s'></td> </tr>\n",
	$text{'edit_args'}, $ptymode eq 'l' ? $args : '';

printf "<tr> <td><input type=radio name=mode value=1 %s> %s</td>\n",
	$ptymode eq 'L' ? 'checked' : '', $text{'edit_mode1'};
printf "<td nowrap><b>%s</b> <input name=cmd1 size=15 value='%s'>\n",
	$text{'edit_cmd'}, $ptymode eq 'L' ? $cmd : '';
printf "<b>%s</b> <input name=args1 size=20 value='%s'></td> </tr>\n",
	$text{'edit_args'}, $ptymode eq 'L' ? $args : '';

printf "<tr> <td><input type=radio name=mode value=2 %s> %s</td>\n",
	$rport ? 'checked' : '', $text{'edit_mode2'};
printf "<td nowrap><b>%s</b> <input name=rhost size=20 value='%s'>\n",
	$text{'edit_rhost'}, !$rport ? '' : $rhost ? $rhost : 'localhost';
printf "<b>%s</b> <input name=rport size=6 value='%s'></td> </tr>\n",
	$text{'edit_rport'}, $rport;

print "</table></td></tr></table><br>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header3'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_pem'}</b></td> <td nowrap>\n";
$haspem = $config{'pem_path'} && -r $config{'pem_path'};
if ($in{'new'}) {
	printf "<input type=radio name=pmode value=0 %s> %s\n",
		"", $text{'edit_pem0'};
	printf "<input type=radio name=pmode value=1 %s> %s\n",
		$haspem ? "" : "checked", $text{'edit_pem1'};
	printf "<input type=radio name=pmode value=2 %s> %s\n",
		$haspem ? "checked" : "", $text{'edit_pem2'};
	printf "<input name=pem size=25 value='%s'> %s</td> </tr>\n",
		$haspem ? $config{'pem_path'} : "", &file_chooser_button("pem");
	}
else {
	local $pmode = $pem eq $webmin_pem ? 1 :
		       $pem ? 2 : 0;
	printf "<input type=radio name=pmode value=0 %s> %s\n",
		$pmode == 0 ? "checked" : "", $text{'edit_pem0'};
	printf "<input type=radio name=pmode value=1 %s> %s\n",
		$pmode == 1 ? "checked" : "", $text{'edit_pem1'};
	printf "<input type=radio name=pmode value=2 %s> %s\n",
		$pmode == 2 ? "checked" : "", $text{'edit_pem2'};
	printf "<input name=pem size=25 value='%s'> %s</td> </tr>\n",
		$pmode == 2 ? $pem : "", &file_chooser_button("pem");
	}

print "<tr> <td><b>$text{'edit_tcpw'}</b></td> <td>\n";
printf "<input type=radio name=tcpw_def value=1 %s> %s\n",
	$tcpw ? "" : "checked", $text{'edit_auto'};
printf "<input type=radio name=tcpw_def value=0 %s>\n",
	$tcpw ? "checked" : "";
printf "<input name=tcpw size=15 value='%s'></td> </tr>\n", $tcpw;

print "<tr> <td><b>$text{'edit_cmode'}</b></td> <td>\n";
printf "<input type=radio name=cmode value=0 %s> %s\n",
	$cmode ? "" : "checked", $text{'edit_cmode0'};
printf "<input type=radio name=cmode value=1 %s> %s</td> </tr>\n",
	$cmode ? "checked" : "", $text{'edit_cmode1'};

print "<tr> <td><b>$text{'edit_iface'}</b></td> <td>\n";
printf "<input type=radio name=iface_def value=1 %s> %s\n",
	$iface ? "" : "checked", $text{'edit_auto'};
printf "<input type=radio name=iface_def value=0 %s>\n",
	$iface ? "checked" : "";
printf "<input name=iface size=25 value='%s'></td> </tr>\n", $iface;

print "</table></td></tr></table>\n";
print "<input type=hidden name=args value='$st->{'args'}'>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

