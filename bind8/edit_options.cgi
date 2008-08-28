#!/usr/local/bin/perl
# edit_options.cgi
# Display options for an existing master zone

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
	&error($text{'master_ecannot'});
$access{'opts'} || &error($text{'master_eoptscannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_opts'}, "");

# Start of form for editing zone options
print &ui_form_start("save_master.cgi");
print &ui_hidden("index", $in{'index'});
print &ui_hidden("view", $in{'view'});
print &ui_table_start($text{'master_opts'}, "width=100%", 4);

print &choice_input($text{'master_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print &choice_input($text{'master_notify'}, "notify", $zconf,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);

print &address_input($text{'master_update'}, "allow-update", $zconf);
print &address_input($text{'master_transfer'}, "allow-transfer", $zconf);

print &address_input($text{'master_query'}, "allow-query", $zconf);
print &address_input($text{'master_notify2'}, "also-notify", $zconf);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

# Buttons at end of page
print &ui_hr();
print &ui_buttons_start();

# Move to another view
@views = grep { &can_edit_view($_) } &find("view", $bconf);
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

# Convert to slave zone
if ($access{'slave'}) {
	print &ui_buttons_row("convert_master.cgi",
		$text{'master_convert'},
		$text{'master_convertdesc'},
		&ui_hidden("index", $in{'index'}).
		&ui_hidden("view", $in{'view'}));
	}

print &ui_buttons_end();

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'master_return'});

