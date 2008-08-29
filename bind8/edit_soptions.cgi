#!/usr/local/bin/perl
# edit_soptions.cgi
# Display options for an existing slave or stub zone

require './bind8-lib.pl';
&ReadParse();
$bconf = $conf = &get_config();
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	$conf = $view->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$file = &find_value("file", $zconf);
$dom = $conf->[$in{'index'}]->{'value'};
&can_edit_zone($conf->[$in{'index'}], $view) ||
	&error($text{'slave_ecannot'});
$access{'opts'} || &error($text{'slave_ecannot'});
$desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_opts'}, "");

# Start of the form
print &ui_form_start("save_slave.cgi");
print &ui_hidden("index", $in{'index'});
print &ui_hidden("view", $in{'view'});
print &ui_hidden("slave_stub", $scriptname);
print &ui_table_start($text{'slave_opts'}, "width=100%", 4);

# Master addresses and port
print &address_port_input($text{'slave_masters'},
			  $text{'slave_masterport'},
			  $text{'slave_master_port'}, 
			  $text{'default'}, 
			  "masters",
			  "port",
			  $zconf,
			  5);

# Transfer time max
print &opt_input($text{'slave_max'}, "max-transfer-time-in",
		 $zconf, $text{'default'}, 4, $text{'slave_mins'});

# Slave records file
print &opt_input($text{'slave_file'}, "file", $zconf, $text{'slave_none'}, 40);

print &choice_input($text{'slave_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print &choice_input($text{'slave_notify'}, "notify", $zconf,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);

print &addr_match_input($text{'slave_update'}, "allow-update", $zconf);
print &addr_match_input($text{'slave_transfer'}, "allow-transfer", $zconf);

print &addr_match_input($text{'slave_query'}, "allow-query", $zconf);
print &address_input($text{'slave_notify2'}, "also-notify", $zconf);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

# Buttons at end of page
print &ui_hr();
print &ui_buttons_start();

# Move to a new view
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

# Convert to master zone
if ($access{'master'} && -s &make_chroot($file)) {
	print &ui_buttons_row("convert_slave.cgi",
		$text{'slave_convert'},
		$text{'slave_convertdesc'},
		&ui_hidden("index", $in{'index'}).
		&ui_hidden("view", $in{'view'}));
	}

print &ui_buttons_end();

&ui_print_footer("edit_slave.cgi?index=$in{'index'}&view=$in{'view'}",
		 $text{'master_return'});

