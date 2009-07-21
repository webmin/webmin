
require 'net-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the net module
sub acl_security_form
{
print "<tr> <td valign=top><b>$text{'acl_ifcs'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=ifcs value=2 %s> $text{'yes'}\n",
	$_[0]->{'ifcs'} == 2 ? "checked" : "";
printf "<input type=radio name=ifcs value=1 %s> $text{'acl_view'}\n",
	$_[0]->{'ifcs'} == 1 ? "checked" : "";
printf "<input type=radio name=ifcs value=0 %s> $text{'no'}<br>\n",
	$_[0]->{'ifcs'} ? "" : "checked";
printf "<input type=radio name=ifcs value=3 %s> $text{'acl_ifcs_only'}\n",
	$_[0]->{'ifcs'} == 3 ? "checked" : "";
print "<input name=interfaces3 size=30 value='".$_[0]->{'interfaces'}."'> ",
	&interfaces_chooser_button("interfaces", 1),"<br>\n";
printf "<input type=radio name=ifcs value=4 %s> $text{'acl_ifcs_ex'}\n",
	$_[0]->{'ifcs'} == 4 ? "checked" : "";
print "<input name=interfaces4 size=30 value='".$_[0]->{'interfaces'}."'> ",
	&interfaces_chooser_button("interfaces", 1),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_bootonly'}</b></td>\n";
print "<td>",&ui_radio("bootonly", $_[0]->{'bootonly'},
		 [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_netmask'}</b></td>\n";
print "<td>",&ui_radio("netmask", $_[0]->{'netmask'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_broadcast'}</b></td>\n";
print "<td>",&ui_radio("broadcast", $_[0]->{'broadcast'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_mtu'}</b></td>\n";
print "<td>",&ui_radio("mtu", $_[0]->{'mtu'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_up'}</b></td>\n";
print "<td>",&ui_radio("up", $_[0]->{'up'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_virt'}</b></td>\n";
print "<td>",&ui_radio("virt", $_[0]->{'virt'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_delete'}</b></td>\n";
print "<td>",&ui_radio("delete", $_[0]->{'delete'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_hide'}</b></td>\n";
print "<td>",&ui_radio("hide", $_[0]->{'hide'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_routes'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=routes value=2 %s> $text{'yes'}\n",
	$_[0]->{'routes'} == 2 ? "checked" : "";
printf "<input type=radio name=routes value=1 %s> $text{'acl_view'}\n",
	$_[0]->{'routes'} == 1 ? "checked" : "";
printf "<input type=radio name=routes value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'routes'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_dns'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dns value=2 %s> $text{'yes'}\n",
	$_[0]->{'dns'} == 2 ? "checked" : "";
printf "<input type=radio name=dns value=1 %s> $text{'acl_view'}\n",
	$_[0]->{'dns'} == 1 ? "checked" : "";
printf "<input type=radio name=dns value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'dns'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_hosts'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=hosts value=2 %s> $text{'yes'}\n",
	$_[0]->{'hosts'} == 2 ? "checked" : "";
printf "<input type=radio name=hosts value=1 %s> $text{'acl_view'}\n",
	$_[0]->{'hosts'} == 1 ? "checked" : "";
printf "<input type=radio name=hosts value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'hosts'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_apply'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=apply value=2 %s> $text{'yes'}\n",
	$_[0]->{'apply'} == 1 ? "checked" : "";
printf "<input type=radio name=apply value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'apply'} ? "" : "checked";
}

# acl_security_save(&options)
# Parse the form for security options for the file module
sub acl_security_save
{
$_[0]->{'ifcs'} = $in{'ifcs'};
$_[0]->{'routes'} = $in{'routes'};
$_[0]->{'dns'} = $in{'dns'};
$_[0]->{'hosts'} = $in{'hosts'};
$_[0]->{'interfaces'} = $in{'ifcs'} == 3 ? $in{'interfaces3'} :
			$in{'ifcs'} == 4 ? $in{'interfaces4'} : undef;
$_[0]->{'apply'} = $in{'apply'};
$_[0]->{'bootonly'} = $in{'bootonly'};
$_[0]->{'netmask'} = $in{'netmask'};
$_[0]->{'broadcast'} = $in{'broadcast'};
$_[0]->{'mtu'} = $in{'mtu'};
$_[0]->{'up'} = $in{'up'};
$_[0]->{'virt'} = $in{'virt'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'hide'} = $in{'hide'};
}

