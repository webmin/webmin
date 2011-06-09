#!/usr/bin/perl
# $Id: edit_zones.cgi,v 1.4 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Edit or create zone directives (pass to save_zones.cgi)

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();
$in{'new'} || (($par, $zone) = &get_branch('zone'));
$sconf = $zone->{'members'};

# display
&ui_print_header(undef, $in{'new'} ? $text{'zone_crheader'} : $text{'zone_eheader'}, "");

print "<form action=save_zones.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'zone_tabhdr'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'zone_desc'}</b></td>\n";
printf "<td colspan=3><input name=desc size=60 value='%s'></td> </tr>\n",
	$zone ? &html_escape($zone->{'comment'}) : "";

print "<tr> <td><b>$text{'zone_name'}</b></td>\n";
printf "<td colspan=3><input name=name size=60 value='%s'></td> </tr>\n",
	$zone ? &html_escape($zone->{'value'}) : "";

print "<tr> <td><b>$text{'zone_primary'}</b></td>\n";
printf "<td colspan=3><input name=primary size=15 value='%s'></td> </tr>\n",
	$zone ? &html_escape(find_value("primary",$zone->{'members'})) : "";


print "<tr>\n";
@keys = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } (find("key", $conf));
print "<td valign=top align=left><b>$text{'zone_tsigkey'}</b></td>\n";
print "<td><select name=key size=1>\n";
local $keyname=find_value("key",$zone->{'members'});
foreach $k (@keys) {
	$curkeyname=$k->{'values'}->[0];
	printf "<option value=\"%s\" %s>%s</option>\n",
		$curkeyname,
		(!$in{'new'} &&  $curkeyname eq $keyname ? "selected" : ""),
		$curkeyname;
	}
print "</select></td>\n";




print "</table></td></tr>\n";
print "</table>\n";

print "<table width=100%><tr>\n";
if (!$in{'new'}) {
	print "<input type=hidden name=idx value=\"$in{'idx'}\">\n";
	print "<td align=left><input type=submit value=\"$text{'save'}\"></td>\n";
	print "<td align=right><input type=submit name=delete ", "value=\"$text{'delete'}\"></td>\n";
}
else {
	print "<td align=left><input type=hidden name=new value=1>\n";
	print "<input type=submit value=\"$text{'create'}\"></td>\n";
}
print "</tr></table>\n";

print "</form>\n";
&ui_print_footer("", $text{'zone_return'});
