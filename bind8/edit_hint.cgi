#!/usr/local/bin/perl
# edit_hint.cgi
# Display information about the hint (root) zone
use strict;
use warnings;
our (%in, %text);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'hint_ecannot'});

&ui_print_header(undef, $text{'hint_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print $text{'hint_desc'},"<p>\n";

print &ui_buttons_start();

# Re-fetch master file button
print &ui_buttons_row("refetch.cgi",
		      $text{'hint_refetch'},
		      $text{'hint_refetchdesc'},
		      &ui_hidden("zone", $in{'zone'}).
		      &ui_hidden("view", $in{'view'}));

# Delete button
print &ui_buttons_row(
	"delete_zone.cgi",
        $text{'hint_delete'},
        $text{'hint_deletedesc'},
        &ui_hidden("zone", $in{'zone'}).
        &ui_hidden("view", $in{'view'}));

print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

