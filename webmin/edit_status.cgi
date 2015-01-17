#!/usr/local/bin/perl
# Display status collection options

require './webmin-lib.pl';
&foreign_require("system-status");
&ui_print_header(undef, $text{'status_title'}, "");

print &ui_form_start("change_status.cgi", "post");
print &ui_table_start($text{'status_header'}, undef, 2);

# Status collection enabled and gap
$i = $system_status::config{'collect_interval'};
print &ui_table_row($text{'status_interval'},
	&ui_opt_textbox("interval", $i eq 'none' ? undef : $i, 5,
			$text{'status_interval1'}, $text{'status_interval0'}).
	" ".$text{'status_mins'});

# Collect packages?
print &ui_table_row($text{'status_pkgs'},
	&ui_yesno_radio("pkgs", $system_status::config{'collect_pkgs'}));

# Collect drive temps?
print &ui_table_row($text{'status_temp'},
	&ui_yesno_radio("temp", !$system_status::config{'collect_notemp'}));

# Units for temps
print &ui_table_row($text{'status_units'},
	&ui_radio("units", $system_status::config{'collect_units'} || 0,
		  [ [ 0, $text{'status_celsius'} ],
		    [ 1, $text{'status_fahrenheit'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

