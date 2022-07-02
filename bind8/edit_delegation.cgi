#!/usr/local/bin/perl
# edit_delegation.cgi
# Display options for an existing delegation-only
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %in, %text);

require './bind8-lib.pl';
&ReadParse();

$in{'view'} = 'any' if ($in{'view'} eq '');
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $z = &zone_to_config($zone);
my $zconf = $z->{'members'};
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

&ui_print_header(&zone_subhead($zone), $text{'delegation_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print "<b>$text{'delegation_noopts'}</b><p>\n";

if (!$access{'ro'}) {
	print &ui_hr();
	print &ui_buttons_start();

	# Move to another view
	my $bconf = &get_config();
	print &move_zone_button($bconf, $zone->{'viewindex'}, $in{'zone'});

	# Delete zone
	if ($access{'delete'}) {
		print &ui_buttons_row("delete_zone.cgi",
			$text{'master_del'}, $text{'delegation_delmsg'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}
&ui_print_footer("", $text{'index_return'});

