#!/usr/local/bin/perl
# edit_record.cgi
# Edit an existing record of some type

require './dns-lib.pl';
&ReadParse();
$conf = &get_config();
$zconf = $conf->[$in{'index'}];
$dom = $zconf->{'values'}->[0];
%access = &get_module_acl();
&can_edit_zone(\%access, $dom) ||
        &error("You are not allowed to edit records in this zone");
&header("Edit $code_map{$in{'type'}}", "");
print "<center><font size=+2>In ",&arpa_to_ip($dom),"</font></center>\n";
print &ui_hr();

@recs = &read_zone_file($zconf->{'values'}->[1], $zconf->{'values'}->[0]);
&foreign_call("bind8", "record_input", $in{'index'}, undef, $in{'type'},
	      $zconf->{'values'}->[1], $zconf->{'values'}->[0], $in{'num'},
	      $recs[$in{'num'}]);
print &ui_hr();
&footer("edit_recs.cgi?index=$in{'index'}&type=$in{'type'}", "records");

