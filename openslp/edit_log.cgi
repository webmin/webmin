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
&ui_print_header(undef, $text{'log_title'}, "");

local $log = &get_log_config();
print "<form action=save_log.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'log_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($log->{'traceDATraffic'} !~ /^true$/i || $log->{'traceDATrafficDisabled'}) {
        $false = " checked";
} else {
        $true = " checked";
}
print "<tr><td><b>$text{'log_traceDATraffic'}</b></td><td nowrap>\n";
print "<input type=radio name=traceDATraffic value=1$true>\n";
print "True&nbsp;&nbsp;<BR>";
print "<input type=radio name=traceDATraffic value=0$false>\n";
print "False&nbsp;(default)";
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
 
local $true=""; local $false="";
if ($log->{'traceMsg'} !~ /^true$/i || $log->{'traceMsgDisabled'}) {
        $false = " checked";
} else {
        $true = " checked";
}
print "<td><b>$text{'log_traceMsg'}</b></td><td nowrap>\n";
print "<input type=radio name=traceMsg value=1$true>\n";
print "True&nbsp;<BR>";
print "<input type=radio name=traceMsg value=0$false>\n";
print "False&nbsp;(default)&nbsp;";
print "</td></tr>\n";
 
print "<tr><td colspan=6><HR></td></tr>";
 
$true=""; $false="";
if ($log->{'traceDrop'} !~ /^true$/i || $log->{'traceDropDisabled'}) {
        $false = " checked";
} else {
        $true = " checked";
}
print "<tr><td><b>$text{'log_traceDrop'}</b></td><td nowrap>\n";
print "<input type=radio name=traceDrop value=1$true>\n";
print "True&nbsp;<BR>";
print "<input type=radio name=traceDrop value=0$false>\n";
print "False&nbsp;(default)&nbsp;";
print "</td>\n";
print "<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
 
$true=""; $false="";
if ($log->{'traceReg'} !~ /^true$/i || $log->{'traceRegDisabled'}) {
        $false = " checked";
} else {
        $true = " checked";
}
print "<td><b>$text{'log_traceReg'}</b></td><td nowrap>\n";
print "<input type=radio name=traceReg value=1$true>\n";
print "True&nbsp;<BR>";
print "<input type=radio name=traceReg value=0$false>\n";
print "False&nbsp;(default)&nbsp;";
print "</td>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

