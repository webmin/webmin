#!/usr/local/bin/perl
# edit_forward.cgi
# Display options for an existing forward zone

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
	&error($text{'fwd_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'fwd_title'}, "");

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
			$text{'master_del'}, $text{'fwd_delmsg'},
			&ui_hidden("index", $in{'index'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}
&ui_print_footer("", $text{'index_return'});

