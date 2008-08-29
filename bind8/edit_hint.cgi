#!/usr/local/bin/perl
# edit_hint.cgi
# Display information about the hint (root) zone

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'hint_ecannot'});

&ui_print_header(undef, $text{'hint_title'}, "");

print $text{'hint_desc'},"<p>\n";

print &ui_buttons_start();

# Re-fetch master file button
print &ui_buttons_row("refetch.cgi",
		      $text{'hint_refetch'},
		      $text{'hint_refetchdesc'},
		      &ui_hidden("index", $in{'index'}).
		      &ui_hidden("view", $in{'view'}));

# Delete button
print &ui_buttons_row(
	"delete_zone.cgi",
        $text{'hint_delete'},
        $text{'hint_deletedesc'},
        &ui_hidden("index", $in{'index'}).
        &ui_hidden("view", $in{'view'}));

print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

