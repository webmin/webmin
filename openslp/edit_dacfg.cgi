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
&ui_print_header(undef, $text{'dacfg_title'}, "");

local $dacfg = &get_dacfg_config();
print "<form action=save_dacfg.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'dacfg_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

local $true=""; local $false="";
if ($dacfg->{'isDA'} !~ /^true$/i || $dacfg->{'isDADisabled'}) {
        $false = " checked";
} else {
        $true = " checked";
}                                                                                                                   
print "<tr><td><b>$text{'dacfg_isDA'}</b></td><td nowrap>\n";
print "<table><tr><td nowrap>\n";
print "<input type=radio name=isDA value=1$true>\n";
print "True&nbsp;<BR>\n";
print "<input type=radio name=isDA value=0$false>\n";
print "False&nbsp;(default)&nbsp;";
print "</td></tr></table></td></tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

