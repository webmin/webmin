
require 'sendmail-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the sendmail module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_opts'}</b></td> <td>\n";
printf "<input type=radio name=opts value=1 %s> $text{'yes'}\n",
	$_[0]->{'opts'} ? "checked" : "";
printf "<input type=radio name=opts value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'opts'} ? "" : "checked";

print "<td><b>$text{'acl_cws'}</b></td> <td>\n";
printf "<input type=radio name=cws value=1 %s> $text{'yes'}\n",
	$_[0]->{'cws'} ? "checked" : "";
printf "<input type=radio name=cws value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'cws'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_masq'}</b></td> <td>\n";
printf "<input type=radio name=masq value=1 %s> $text{'yes'}\n",
	$_[0]->{'masq'} ? "checked" : "";
printf "<input type=radio name=masq value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'masq'} ? "" : "checked";

print "<td><b>$text{'acl_trusts'}</b></td> <td>\n";
printf "<input type=radio name=trusts value=1 %s> $text{'yes'}\n",
	$_[0]->{'trusts'} ? "checked" : "";
printf "<input type=radio name=trusts value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'trusts'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_cgs'}</b></td> <td>\n";
printf "<input type=radio name=cgs value=1 %s> $text{'yes'}\n",
	$_[0]->{'cgs'} ? "checked" : "";
printf "<input type=radio name=cgs value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'cgs'} ? "" : "checked";

print "<td><b>$text{'acl_relay'}</b></td> <td>\n";
printf "<input type=radio name=relay value=1 %s> $text{'yes'}\n",
	$_[0]->{'relay'} ? "checked" : "";
printf "<input type=radio name=relay value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'relay'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_mailers'}</b></td> <td>\n";
printf "<input type=radio name=mailers value=1 %s> $text{'yes'}\n",
	$_[0]->{'mailers'} ? "checked" : "";
printf "<input type=radio name=mailers value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'mailers'} ? "" : "checked";

print "<td><b>$text{'acl_access'}</b></td> <td>\n";
printf "<input type=radio name=access value=1 %s> $text{'yes'}\n",
	$_[0]->{'access'} ? "checked" : "";
printf "<input type=radio name=access value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'access'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_domains'}</b></td> <td>\n";
printf "<input type=radio name=domains value=1 %s> $text{'yes'}\n",
	$_[0]->{'domains'} ? "checked" : "";
printf "<input type=radio name=domains value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'domains'} ? "" : "checked";

print "<td><b>$text{'acl_stop'}</b></td> <td>\n";
printf "<input type=radio name=stop value=1 %s> $text{'yes'}\n",
	$_[0]->{'stop'} ? "checked" : "";
printf "<input type=radio name=stop value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'stop'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_manual'}</b></td> <td>\n";
printf "<input type=radio name=manual value=1 %s> $text{'yes'}\n",
	$_[0]->{'manual'} ? "checked" : "";
printf "<input type=radio name=manual value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'manual'} ? "" : "checked";

print "<td><b>$text{'acl_mailq'}</b></td> <td><select name=mailq>\n";
printf "<option value=2 %s>$text{'acl_viewdel'}</option>\n",
	$_[0]->{'mailq'} == 2 ? "selected" : "";
printf "<option value=1 %s>$text{'acl_view'}</option>\n",
	$_[0]->{'mailq'} == 1 ? "selected" : "";
printf "<option value=0 %s>$text{'no'}</option>\n",
	$_[0]->{'mailq'} == 0 ? "selected" : "";
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_qdoms'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=qdoms_def value=1 %s> %s\n",
	$_[0]->{'qdoms'} ? "" : "checked", $text{'acl_all'};
printf "<input type=radio name=qdoms_def value=0 %s> %s\n",
	$_[0]->{'qdoms'} ? "checked" : "", $text{'acl_matching'};
printf "<input name=qdoms size=40 value='%s'></td> </tr>\n",
	$_[0]->{'qdoms'};

print "<tr> <td><b>$text{'acl_qdomsmode'}</b></td> <td colspan=3>\n";
foreach $m (0 .. 2) {
	printf "<input type=radio name=qdomsmode value=%s %s> %s\n",
		$m, $_[0]->{'qdomsmode'} == $m ? "checked" : "",
		$text{'acl_qdomsmode'.$m};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_flushq'}</b></td> <td>\n";
printf "<input type=radio name=flushq value=1 %s> $text{'yes'}\n",
	$_[0]->{'flushq'} ? "checked" : "";
printf "<input type=radio name=flushq value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'flushq'} ? "" : "checked";

print "<td><b>$text{'acl_ports'}</b></td> <td>\n";
printf "<input type=radio name=ports value=1 %s> $text{'yes'}\n",
	$_[0]->{'ports'} ? "checked" : "";
printf "<input type=radio name=ports value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'ports'} ? "" : "checked";

# Virtusers
print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_virtusers'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=vmode value=0 %s> $text{'acl_none'}\n",
	$_[0]->{'vmode'} == 0 ? "checked" : "";
printf "<input type=radio name=vmode value=1 %s> $text{'acl_all'}\n",
	$_[0]->{'vmode'} == 1 ? "checked" : "";
printf "<input type=radio name=vmode value=3 %s> $text{'acl_vsame'}<br>\n",
	$_[0]->{'vmode'} == 3 ? "checked" : "";
printf "<input type=radio name=vmode value=2 %s> $text{'acl_matching'}\n",
	$_[0]->{'vmode'} == 2 ? "checked" : "";
printf "<input name=vaddrs size=40 value='%s'></td> </tr>\n",
	$_[0]->{'vaddrs'};

print "<tr> <td><b>$text{'acl_vtypes'}</b></td>\n";
print "<td colspan=3>\n";
for($n=0; $n<3; $n++) {
	printf "<input type=checkbox name=vedit_%s value=1 %s> %s\n",
		$n, $_[0]->{"vedit_$n"} ? "checked" : "", $text{"acl_vtype$n"};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_vmax'}</b></td>\n";
printf "<td><input type=radio name=vmax_def value=1 %s> %s\n",
	$_[0]->{'vmax'} ? "" : "checked", $text{'acl_unlimited'};
printf "<input type=radio name=vmax_def value=0 %s>\n",
	$_[0]->{'vmax'} ? "checked" : "";
printf "<input name=vmax size=5 value='%s'></td>\n",
	$_[0]->{'vmax'};

print "<td><b>$text{'acl_vcatchall'}</b></td>\n";
print "<td>",&ui_yesno_radio("vcatchall",
			     int($_[0]->{'vcatchall'})),"</td> </tr>\n";

# Aliases
print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_aliases'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=amode value=0 %s> $text{'acl_none'}\n",
	$_[0]->{'amode'} == 0 ? "checked" : "";
printf "<input type=radio name=amode value=1 %s> $text{'acl_all'}\n",
	$_[0]->{'amode'} == 1 ? "checked" : "";
printf "<input type=radio name=amode value=3 %s> $text{'acl_asame'}<br>\n",
	$_[0]->{'amode'} == 3 ? "checked" : "";
printf "<input type=radio name=amode value=2 %s> $text{'acl_matching'}\n",
	$_[0]->{'amode'} == 2 ? "checked" : "";
printf "<input name=aliases size=40 value='%s'></td> </tr>\n",
	$_[0]->{'aliases'};

print "<tr> <td><b>$text{'acl_atypes'}</b></td> <td colspan=3>\n";
for($n=1; $n<=6; $n++) {
	printf "<input type=checkbox name=aedit_%s value=1 %s> %s\n",
		$n, $_[0]->{"aedit_$n"} ? "checked" : "",
		$text{"acl_atype$n"};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_amax'}</b></td>\n";
printf "<td colspan=3><input type=radio name=amax_def value=1 %s> %s\n",
	$_[0]->{'amax'} ? "" : "checked", $text{'acl_unlimited'};
printf "<input type=radio name=amax_def value=0 %s>\n",
	$_[0]->{'amax'} ? "checked" : "";
printf "<input name=amax size=5 value='%s'></td> </tr>\n",
	$_[0]->{'amax'};

print "<tr> <td><b>$text{'acl_apath'}</b></td>\n";
printf "<td colspan=3><input name=apath size=40 value='%s'> %s</td> </tr>\n",
	$_[0]->{'apath'}, &file_chooser_button("apath", 1);

# Outgoing address mappings
print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_outgoing'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=omode value=0 %s> $text{'acl_none'}\n",
	$_[0]->{'omode'} == 0 ? "checked" : "";
printf "<input type=radio name=omode value=1 %s> $text{'acl_all'}<br>\n",
	$_[0]->{'omode'} == 1 ? "checked" : "";
printf "<input type=radio name=omode value=2 %s> $text{'acl_matching'}\n",
	$_[0]->{'omode'} == 2 ? "checked" : "";
printf "<input name=oaddrs size=40 value='%s'></td> </tr>\n",
	$_[0]->{'oaddrs'};

# Spam control rules
print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_spam'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=smode value=1 %s> $text{'acl_all'}\n",
	$_[0]->{'smode'} == 1 ? "checked" : "";
printf "<input type=radio name=smode value=2 %s> $text{'acl_matching'}\n",
	$_[0]->{'smode'} == 2 ? "checked" : "";
printf "<input name=saddrs size=40 value='%s'></td> </tr>\n",
	$_[0]->{'saddrs'};
}

# acl_security_save(&options)
# Parse the form for security options for the sendmail module
sub acl_security_save
{
$_[0]->{'opts'} = $in{'opts'};
$_[0]->{'ports'} = $in{'ports'};
$_[0]->{'cws'} = $in{'cws'};
$_[0]->{'masq'} = $in{'masq'};
$_[0]->{'trusts'} = $in{'trusts'};
$_[0]->{'cgs'} = $in{'cgs'};
$_[0]->{'relay'} = $in{'relay'};
$_[0]->{'manual'} = $in{'manual'};
$_[0]->{'mailq'} = $in{'mailq'};
$_[0]->{'qdoms'} = $in{'qdoms_def'} ? undef : $in{'qdoms'};
$_[0]->{'qdomsmode'} = $in{'qdomsmode'};
$_[0]->{'mailers'} = $in{'mailers'};
$_[0]->{'access'} = $in{'access'};
$_[0]->{'domains'} = $in{'domains'};
$_[0]->{'stop'} = $in{'stop'};
$_[0]->{'vmode'} = $in{'vmode'};
$_[0]->{'vaddrs'} = $in{'vmode'} == 2 ? $in{'vaddrs'} : "";
$_[0]->{'vmax'} = $in{'vmax_def'} ? undef : $in{'vmax'};
foreach $i (0..2) {
	$_[0]->{"vedit_$i"} = $in{"vedit_$i"};
	}
$_[0]->{'vcatchall'} = $in{'vcatchall'};
$_[0]->{'amode'} = $in{'amode'};
$_[0]->{'aliases'} = $in{'amode'} == 2 ? $in{'aliases'} : "";
$_[0]->{'amax'} = $in{'amax_def'} ? undef : $in{'amax'};
$_[0]->{'apath'} = $in{'apath'};
foreach $i (1..6) {
	$_[0]->{"aedit_$i"} = $in{"aedit_$i"};
	}
$_[0]->{'omode'} = $in{'omode'};
$_[0]->{'oaddrs'} = $in{'omode'} == 2 ? $in{'oaddrs'} : "";
$_[0]->{'flushq'} = $in{'flushq'};
$_[0]->{'smode'} = $in{'smode'};
$_[0]->{'saddrs'} = $in{'smode'} == 2 ? $in{'saddrs'} : "";
}

