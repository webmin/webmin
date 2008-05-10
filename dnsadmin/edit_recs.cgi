#!/usr/local/bin/perl
# edit_recs.cgi
# Display records of some type from some domain

require './dns-lib.pl';
&ReadParse();
$conf = &get_config();
$zconf = $conf->[$in{'index'}];
$dom = $zconf->{'values'}->[0];
%access = &get_module_acl();
&can_edit_zone(\%access, $dom) ||
        &error("You are not allowed to edit records in this zone");
&header("$code_map{$in{'type'}} Records", "");
print "<center><font size=+2>In ",&arpa_to_ip($dom),"</font></center>\n";
print "<hr><p>\n";

$file = $zconf->{'values'}->[1];
&foreign_call("bind8", "record_input", $in{'index'}, undef, $in{'type'}, $file, $dom);
@recs = &read_zone_file($file, $dom);
@recs = grep { $_->{'type'} eq $in{'type'} } @recs;
if (@recs) {
	@recs = &sort_records(@recs);
        %hmap = ( "A", [ "Address" ],
                  "NS", [ "Name Server" ],
                  "CNAME", [ "Real Name" ],
                  "MX", [ "Priority", "Mail Server" ],
                  "HINFO", [ "Hardware", "Operating System" ],
                  "TXT", [ "Message" ],
                  "WKS", [ "Address", "Protocol", "Service" ],
                  "RP", [ "Email Address", "Text Record" ],
                  "PTR", [ "Hostname" ] );
        if ($in{'type'} =~ /HINFO|WKS|RP/) {
                &recs_table(@recs);
                }
        else {
                $mid = int((@recs+1)/2);
                print "<table width=100%><tr><td width=50% valign=top>\n";
                &recs_table(@recs[0 .. $mid-1]);
                print "</td><td width=50% valign=top>\n";
                if ($mid < @recs) { &recs_table(@recs[$mid .. $#recs]); }
                print "</td></tr></table><p>\n";
                }
        print "<p>\n";
        }
print &ui_hr();
&footer("edit_master.cgi?index=$in{'index'}", "record types");

sub recs_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",$in{'type'} eq "PTR" ? "Address" : "Name",
      "</b></td> <td><b>TTL</b></td>\n";
@hmap = @{$hmap{$in{'type'}}};
foreach $h (@hmap) {
        print "<td><b>$h</b></td>\n";
        }
print "</tr>\n";
for($i=0; $i<@_; $i++) {
        $r = $_[$i];
        $name = &html_escape($in{'type'} eq "PTR" ? &arpa_to_ip($r->{'name'})
						  : $r->{'name'});
        print "<tr $cb> <td><a href=\"edit_record.cgi?index=",
              "$in{'index'}&type=$in{'type'}&num=$r->{'num'}\">$name",
              "</a></td>\n";
        print "<td>",$r->{'ttl'} ? $r->{'ttl'} : "Default","</td>\n";
        for($j=0; $j<@hmap; $j++) {
                print "<td>",&html_escape($r->{'values'}->[$j]),"</td>\n";
                }
        print "</tr>\n";
        }
print "</table>\n";
}

