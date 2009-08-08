#!/usr/local/bin/perl
# edit_options.cgi
# Display options for an existing master zone

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name($in{'index'}, $in{'view'});
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
&ui_print_header($desc, $text{'master_opts'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

# Start of form for editing zone options
print &ui_form_start("save_master.cgi", "post");
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

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'master_return'});

