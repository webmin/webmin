#!/usr/local/bin/perl
# edit_master.cgi
# Display a form for editing a master domain

require './dns-lib.pl';
&ReadParse();
$conf = &get_config();
$zconf = $conf->[$in{'index'}];
$dom = $zconf->{'values'}->[0];
%access = &get_module_acl();
&can_edit_zone(\%access, $dom) ||
	&error("You are not allowed to edit this zone");
&header("Edit Master Zone", "");
print "<center><font size=+2>",&arpa_to_ip($dom),"</font></center>\n";

print "<hr><p>\n";
@recs = &read_zone_file($zconf->{'values'}->[1], $dom);
if ($dom =~ /in-addr.arpa/i) {
        @rcodes = ("PTR", "NS");
        }
else {
        @rcodes = ("A", "NS", "CNAME", "MX", "HINFO", "TXT", "WKS", "RP");
        }
foreach $c (@rcodes) { $rnum{$c} = 0; }
foreach $r (@recs) {
        $rnum{$r->{'type'}}++;
        if ($r->{'type'} eq "SOA") { $soa = $r; }
        }
if ($config{'show_list'}) {
        # display as list
        $mid = int((@rcodes+1)/2);
        print "<table width=100%> <tr><td width=50%>\n";
        &types_table(@rcodes[0..$mid-1]);
        print "</td><td width=50%>\n";
        &types_table(@rcodes[$mid..$#rcodes]);
        print "</td></tr> </table>\n";
        }
else {
        # display as icons
        for($i=0; $i<@rcodes; $i++) {
                push(@rlinks,
                     "edit_recs.cgi?index=$in{'index'}&type=$rcodes[$i]");
                push(@rtitles, "$code_map{$rcodes[$i]} ($rnum{$rcodes[$i]})");
                push(@ricons, "../bind8/images/$rcodes[$i].gif");
                }
        &icons_table(\@rlinks, \@rtitles, \@ricons);
        }
$file = &absolute_path($zconf->{'values'}->[1]);
print "<a href=\"edit_text.cgi?index=$in{'index'}\">Manually edit ",
      "records file</a><br>\n";

# form for editing SOA record
$v = $soa->{'values'};
print "<hr><a name=soa>\n";
print "<form action=save_master.cgi>\n";
print "<input type=hidden name=file value=\"$soa->{'file'}\">\n";
print "<input type=hidden name=num value=\"$soa->{'num'}\">\n";
print "<input type=hidden name=origin value=\"$dom\">\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>Master Zone Parameters</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>Master server</b></td>\n";
print "<td><input name=master size=20 value=\"$v->[0]\"></td>\n";
$v->[1] =~ s/\./\@/; $v->[1] =~ s/\.$//;
print "<td><b>Email address</b></td>\n";
print "<td><input name=email size=20 value=\"$v->[1]\"></td> </tr>\n";

print "<tr> <td><b>Refresh time</b></td>\n";
print "<td><input name=refresh size=10 value=\"$v->[3]\"> secs</td>\n";
print "<td><b>Transfer retry time</b></td>\n";
print "<td><input name=retry size=10 value=\"$v->[4]\"> secs</td> </tr>\n";

print "<tr> <td><b>Expiry time</b></td>\n";
print "<td><input name=expiry size=10 value=\"$v->[5]\"> secs</td>\n";
print "<td><b>Default time-to-live</b></td>\n";
print "<td><input name=minimum size=10 value=\"$v->[6]\"> secs</td> </tr>\n";

print "</table></td></tr> </table>\n";
print "<table width=100%><tr><td valign=top align=left>\n";
print "<input type=submit value=Save></td></form>\n";
print "<form action=delete_zone.cgi>\n";
print "<input type=hidden name=index value=\"$in{'index'}\">\n";
print "<td align=right><input type=submit value=Delete>\n";
print "</td></form> </tr></table>\n";

print &ui_hr();
&footer("", "zone list");

sub types_table
{
if ($_[0]) {
        local($i);
        print "<table border width=100%>\n";
        print "<tr $tb> <td><b>Type</b></td> <td><b>Records</b></td> </tr>\n";
        for($i=0; $_[$i]; $i++) {
                print "<tr $cb> <td><a href=\"edit_recs.cgi?",
                      "index=$in{'index'}&type=$_[$i]\">$code_map{$_[$i]}",
                      "</a></td>\n";
                print "<td>$rnum{$_[$i]}</td> </tr>\n";
                }
        print "</table>\n";
        }
}

