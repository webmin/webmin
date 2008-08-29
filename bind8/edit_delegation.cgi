#!/usr/local/bin/perl
# edit_delegation.cgi
# Display options for an existing delegation-only

require './bind8-lib.pl';
&ReadParse();
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$dom = $conf->[$in{'index'}]->{'value'};
&can_edit_zone($conf->[$in{'index'}], $view) ||
	&error($text{'delegation_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'delegation_title'}, "");

print "<b>$text{'delegation_noopts'}</b><p>\n";

if (!$access{'ro'}) {
	print &ui_hr();
	print &ui_buttons_start();

	# Move to another view
	@views = &find("view", $bconf);
	if ($in{'view'} eq '' && @views || $in{'view'} ne '' && @views > 1) {
		print &ui_buttons_row("move_zone.cgi",
			$text{'master_move'},
			$text{'master_movedesc'},
			&ui_hidden("index", $in{'index'}).
			&ui_hidden("view", $in{'view'}),
			&ui_select("newview", undef,
			  map { [ $_->{'index'}, $_->{'view'} ] }
			    grep { $_->{'index'} ne $in{'view'} } @views));
		}

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

