#!/usr/bin/perl
# $Id: edit_zones.cgi,v 1.4 2005/04/16 14:30:21 jfranken Exp $
# File added 2005-04-15 by Johannes Franken <jfranken@jfranken.de>
# Distributed under the terms of the GNU General Public License, v2 or later
#
# * Edit or create zone directives (pass to save_zones.cgi)

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
%access = &get_module_acl();
$access{'zones'} || &error($text{'zone_ecannot'});
$conf = &get_config();
$in{'new'} || (($par, $zone) = &get_branch('zone'));
$sconf = $zone->{'members'};

# display
&ui_print_header(undef, $in{'new'} ? $text{'zone_crheader'} : $text{'zone_eheader'}, "");

print &ui_form_start("save_zones.cgi", "post");
print &ui_table_start($text{'zone_tabhdr'}, "width=100%", 2);
print &ui_table_row($text{'zone_desc'}, &ui_textbox("desc", ($zone ? &html_escape($zone->{'comment'}) : ""), 60) );
print &ui_table_row($text{'zone_name'}, &ui_textbox("name", ($zone ? &html_escape($zone->{'value'}) : ""), 60) );
print &ui_table_row($text{'zone_primary'}, &ui_textbox("primary", ($zone ? &html_escape(find_value("primary",$zone->{'members'})) : ""), 15) );

my @keys = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } (find("key", $conf));
my $keyname=find_value("key",$zone->{'members'});
my @key_sel;
foreach $k (@keys) {
	$curkeyname=$k->{'values'}->[0];
    push(@key_sel, [$curkeyname, $curkeyname, (!$in{'new'} && $curkeyname eq $keyname ? "selected" : "") ] );
	}

print &ui_table_row($text{'zone_tsigkey'}, &ui_select("key", undef, \@key_sel, 1) );

print &ui_table_end();

if (!$in{'new'}) {
    print &ui_hidden("idx", $in{'idx'});
	print &ui_submit($text{'save'})."&nbsp;".&ui_submit($text{'delete'},"delete");
}
else {
    print &ui_hidden("new",1);
    print &ui_submit($text{'create'});
}

print &ui_form_end();


&ui_print_footer("", $text{'zone_return'});
