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
&ui_print_header(undef, $text{'snda_title'}, "");

local $snda = &get_snda_config();
print "<form action=save_snda.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'snda_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($snda->{'useScopesDisabled'}) {
	$true = " checked";
	}
else {
	$false = " checked";
	}
print "<tr><td><b>$text{'snda_useScopes'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=useScopes value=1$true>\n";
print "&nbsp;Default&nbsp;&nbsp;";
print "<input type=radio name=useScopes value=0$false></td><td>\n";
for($i=0; $i<3; $i++) {
	printf "<input name=useScopesValue_$i size=20 value=\"%s\"><br>\n",
		$snda->{'useScopes'}->[$i];
	}
print "</td></tr></table></td></tr>\n";
print "<tr><td colspan=3><HR></td></tr>";

local $true=""; local $false="";
if ($snda->{'DAAddressesDisabled'}) {
	$true = " checked";
	}
else {
	$false = " checked";
	}
print "<tr><td><b>$text{'snda_DAAddresses'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=DAAddresses value=1$true>\n";
print "&nbsp;Default&nbsp;&nbsp;";
print "<input type=radio name=DAAddresses value=0$false></td><td>\n";
for($i=0; $i<3; $i++) {
        printf "<input name=DAAddressesValue_$i size=20 value=\"%s\"><br>\n",
                $snda->{'DAAddresses'}->[$i];
        }
print "</td></tr></table></td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

