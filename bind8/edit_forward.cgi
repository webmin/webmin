#!/usr/local/bin/perl
# edit_forward.cgi
# Display options for an existing forward zone

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

$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$dom = $zone->{'name'};
&can_edit_zone($zone, $view) ||
	&error($text{'fwd_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'fwd_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Start of the form
print &ui_form_start("save_forward.cgi");
print &ui_hidden("index", $in{'index'});
print &ui_hidden("view", $in{'view'});
print &ui_table_start($text{'fwd_opts'}, "width=100%", 4);

# Forwarding servers
print &forwarders_input($text{'fwd_masters'}, "forwarders", $zconf);

print &choice_input($text{'fwd_forward'}, "forward", $zconf,
		    $text{'yes'}, "first", $text{'no'}, "only",
		    $text{'default'}, undef);
print &choice_input($text{'fwd_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);

print &ui_table_end();

if ($access{'ro'}) {
	print &ui_form_end();
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);

	print &ui_hr();
	print &ui_buttons_start();

	# Move to another view
	print &move_zone_button($bconf, $in{'view'}, $in{'index'});

	# Delete zone
	if ($access{'delete'}) {
		print &ui_buttons_row("delete_zone.cgi",
			$text{'master_del'}, $text{'fwd_delmsg'},
			&ui_hidden("index", $in{'index'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}
&ui_print_footer("", $text{'index_return'});

