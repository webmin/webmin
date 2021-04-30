#!/usr/local/bin/perl
# Display options specific to mobile devices

require './webmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'mobile_title'}, "");
&get_miniserv_config(\%miniserv);

print &ui_form_start("change_mobile.cgi");
print &ui_table_start($text{'mobile_header'}, undef, 2);

# Custom theme for mobile devices
@themes = &list_themes();
$m = $miniserv{'mobile_preroot'};
print &ui_table_row($text{'mobile_theme'},
	    &ui_select("theme", defined($m) ? $m : "*",
		       [ [ "*", $text{'mobile_themeglob'} ],
			 map { [ $_->{'dir'}, $_->{'desc'} ] } @themes ]), undef, [ "valign=middle","valign=middle" ]);

# Skip session login for mobile devices
print &ui_table_row($text{'mobile_nosession'},
	    &ui_yesno_radio("nosession", int($miniserv{'mobile_nosession'})), undef, [ "valign=middle","valign=middle" ]);

# Extra user agents
print &ui_table_row($text{'mobile_agents'},
	    &ui_textarea("agents",
		join("\n", split(/\t+/, $miniserv{'mobile_agents'})), 5, 50));

# Hostname prefixes for mobile
print &ui_table_row($text{'mobile_prefixes'},
	    &ui_textbox("prefixes", $miniserv{'mobile_prefixes'}, 50), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
