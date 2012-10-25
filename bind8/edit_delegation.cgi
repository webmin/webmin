#!/usr/local/bin/perl
# edit_delegation.cgi
# Display options for an existing delegation-only

require './bind8-lib.pl';
&ReadParse();
if ($in{'zone'}) {
	$zone = &get_zone_name($in{'zone'}, $in{'view'} || 'any');
	$in{'index'} = $zone->{'index'};
	$in{'view'} = $zone->{'viewindex'};
	}
else {
	$zone = &get_zone_name($in{'index'}, $in{'view'});
	}
$dom = $zone->{'name'};

&can_edit_zone($zone, $view) ||
	&error($text{'delegation_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'delegation_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print "<b>$text{'delegation_noopts'}</b><p>\n";

if (!$access{'ro'}) {
	print &ui_hr();
	print &ui_buttons_start();

	# Move to another view
	print &move_zone_button($bconf, $in{'view'}, $in{'index'});

	# Delete zone
	if ($access{'delete'}) {
		print &ui_buttons_row("delete_zone.cgi",
			$text{'master_del'}, $text{'delegation_delmsg'},
			&ui_hidden("index", $in{'index'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}
&ui_print_footer("", $text{'index_return'});

