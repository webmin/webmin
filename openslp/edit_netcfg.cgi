#!/usr/local/bin/perl
#
# An OpenSLP webmin module
# by Monty Charlton <monty@caldera.com>,
#
# Copyright (c) 2000 Caldera Systems
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#

require './slp-lib.pl';
&ui_print_header(undef, $text{'netcfg_title'}, "");

local $netcfg = &get_netcfg_config();
print "<form action=save_netcfg.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'netcfg_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100% cellpadding=2>\n";

if ($netcfg->{'isBroadcastOnly'} !~ /^true$/i || $netcfg->{'isBroadcastOnlyDisabled'}) {
	$false = " checked";
} else {
	$true = " checked";
}
print "<tr><td><b>$text{'netcfg_isBroadcastOnly'}</b></td><td nowrap>\n";
print "<input type=radio name=isBroadcastOnly value=1$true>\n";
print "True&nbsp;&nbsp;<BR>";
print "<input type=radio name=isBroadcastOnly value=0$false>\n";
print "False&nbsp;(default)";
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

local $true=""; local $false="";
if ($netcfg->{'passiveDADetection'} !~ /^false$/i || $netcfg->{'passiveDADetectionDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_passiveDADetection'}</b></td><td nowrap>\n";
print "<input type=radio name=passiveDADetection value=1$true>\n";
print "True&nbsp;(default)&nbsp;<BR>";
print "<input type=radio name=passiveDADetection value=0$false>\n";
print "False&nbsp;";
print "</td></tr>\n";                                                                                               
print "<tr><td colspan=6><HR></td></tr>";

$true=""; $false="";
if ($netcfg->{'activeDADetection'} !~ /^false$/i || $netcfg->{'activeDADetectionDisabled'}) {
        $true = " checked";
} else {
        $false = " checked";
}
print "<tr><td><b>$text{'netcfg_activeDADetection'}</b></td><td nowrap>\n";
print "<input type=radio name=activeDADetection value=1$true>\n";
print "True&nbsp;(default)&nbsp;<BR>";
print "<input type=radio name=activeDADetection value=0$false>\n";
print "False&nbsp;";
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
 
$true=""; $false="";
if ($netcfg->{'DAActiveDiscoveryIntervalDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_DAActiveDiscoveryInterval'}</b></td><td nowrap>\n";
print "<input type=radio name=DAActiveDiscoveryInterval value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=DAActiveDiscoveryInterval value=0$false>\n";
print "&nbsp;";
printf "<input name=DAActiveDiscoveryIntervalValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'DAActiveDiscoveryInterval'};
print "</td>\n";
print "<tr><td colspan=6><HR></td>";

$true=""; $false="";
if ($netcfg->{'multicastTTLDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<tr><td><b>$text{'netcfg_multicastTTL'}</b></td><td nowrap>\n";
print "<input type=radio name=multicastTTL value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=multicastTTL value=0$false>\n";
print "&nbsp;";
printf "<input name=multicastTTLValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'multicastTTL'};
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

$true=""; $false="";
if ($netcfg->{'DADiscoveryMaximumWaitDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_DADiscoveryMaximumWait'}</b></td><td nowrap>\n";
print "<input type=radio name=DADiscoveryMaximumWait value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=DADiscoveryMaximumWait value=0$false>\n";
print "&nbsp;";
printf "<input name=DADiscoveryMaximumWaitValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'DADiscoveryMaximumWait'};
print "</td></tr>\n";
print "<tr><td colspan=6><HR></td>";

$true=""; $false="";
if ($netcfg->{'DADiscoveryTimeoutsDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<tr><td><b>$text{'netcfg_DADiscoveryTimeouts'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=DADiscoveryTimeouts value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=DADiscoveryTimeouts value=0$false></td><td>\n";
for ($i=0; $i<5; $i++) {
	printf "<input name=DADiscoveryTimeoutsValue_$i size=6 value=\"%s\"><br>\n",
		$netcfg->{'DADiscoveryTimeouts'}->[$i];
}
print "</td></tr></table></td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

$true=""; $false="";
if ($netcfg->{'HintsFileDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_HintsFile'}</b></td><td nowrap>\n";
print "<input type=radio name=HintsFile value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=HintsFile value=0$false>\n";
print "&nbsp;";
printf "<input name=HintsFileValue size=13 value=\"%s\"><br>\n",
	$netcfg->{'HintsFile'};
print "</td></tr>\n";
print "<tr><td colspan=6><HR></td>";

$true=""; $false="";
if ($netcfg->{'multicastMaximumWaitDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<tr><td><b>$text{'netcfg_multicastMaximumWait'}</b></td><td nowrap>\n";
print "<input type=radio name=multicastMaximumWait value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=multicastMaximumWait value=0$false>\n";
print "&nbsp;";
printf "<input name=multicastMaximumWaitValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'multicastMaximumWait'};
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

$true=""; $false="";
if ($netcfg->{'multicastTimeoutsDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_multicastTimeouts'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=multicastTimeouts value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=multicastTimeouts value=0$false></td><td>\n";
for ($i=0; $i<5; $i++) {
	printf "<input name=multicastTimeoutsValue_$i size=6 value=\"%s\"><br>\n",
		$netcfg->{'multicastTimeouts'}->[$i];
}
print "</td></tr></table></td><tr>\n";
print "<tr><td colspan=6><HR></td>";

$true=""; $false="";
if ($netcfg->{'unicastMaximumWaitDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<tr><td><b>$text{'netcfg_unicastMaximumWait'}</b></td><td nowrap>\n";
print "<input type=radio name=unicastMaximumWait value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=unicastMaximumWait value=0$false>\n";
print "&nbsp;";
printf "<input name=unicastMaximumWaitValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'unicastMaximumWait'};
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

$true=""; $false="";
if ($netcfg->{'randomWaitBoundDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_randomWaitBound'}</b></td><td nowrap>\n";
print "<input type=radio name=randomWaitBound value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=randomWaitBound value=0$false>\n";
print "&nbsp;";
printf "<input name=randomWaitBoundValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'randomWaitBound'};
print "</td></tr>\n";
print "<tr><td colspan=6><HR></td>";

$true=""; $false="";
if ($netcfg->{'MTUDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<tr><td><b>$text{'netcfg_MTU'}</b></td><td nowrap>\n";
print "<input type=radio name=MTU value=1$true>\n";
print "Default&nbsp;";
print "<input type=radio name=MTU value=0$false>\n";
print "&nbsp;";
printf "<input name=MTUValue size=6 value=\"%s\"><br>\n",
	$netcfg->{'MTU'};
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";

$true=""; $false="";
if ($netcfg->{'interfacesDisabled'}) {
	$true = " checked";
} else {
	$false = " checked";
}
print "<td><b>$text{'netcfg_interfaces'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=interfaces value=1$true>\n";
print "All&nbsp;";
print "<input type=radio name=interfaces value=0$false></td><td>\n";
for ($i=0; $i<5; $i++) {
	printf "<input name=interfacesValue_$i size=13 value=\"%s\"><br>\n",
		$netcfg->{'interfaces'}->[$i];
}
print "</td></tr></table></td><tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

