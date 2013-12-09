#!/usr/local/bin/perl
# edit_ui.cgi
# Edit user interface options

require './webmin-lib.pl';
&ui_print_header(undef, $text{'ui_title'}, "");

print $text{'ui_desc'},"<p>\n";

print &ui_form_start("change_ui.cgi", "post");
print &ui_table_start($text{'ui_header'}, undef, 2);

for($i=0; $i<@cs_names; $i++) {
	$cd = $cs_codes[$i];
	print &ui_table_row($cs_names[$i],
		&ui_opt_textbox($cd, $gconfig{$cd}, 8, $text{'ui_default'},
				$text{'ui_rgb'}), undef, [ "valign=middle","valign=middle" ]);
	}

print &ui_table_row($text{'ui_sysinfo'},
	&ui_select("sysinfo", int($gconfig{'sysinfo'}),
		   [ map { [ $_, $text{'ui_sysinfo'.$_} ] } (0, 1, 4, 2, 3) ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_hostnamemode'},
	&ui_select("hostnamemode", int($gconfig{'hostnamemode'}),
		   [ map { [ $_, $text{'ui_hnm'.$_} ] } (0 .. 3) ]).
	" ".&ui_textbox("hostnamedisplay", $gconfig{'hostnamedisplay'}, 20), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_showlogin'},
	&ui_yesno_radio("showlogin", int($gconfig{'showlogin'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_showhost'},
	&ui_yesno_radio("showhost", int($gconfig{'showhost'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_feedback'},
	&ui_opt_textbox("feedback", $gconfig{'feedback_to'}, 20,
			$webmin_feedback_address), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_feedbackmode'},
	&ui_radio("nofeedbackcc", int($gconfig{'nofeedbackcc'}),
		  [ [ 0, $text{'yes'} ], [ 1, $text{'ui_feednocc'} ],
		    [ 2, $text{'no'} ] ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_dateformat'},
	&ui_select("dateformat", $gconfig{'dateformat'} || "dd/mon/yyyy",
		   [ map { [ $_, $text{'ui_dateformat_'.$_} ] }
			 @webmin_date_formats ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_width'},
	&ui_opt_textbox("width", $gconfig{'help_width'}, 5,
			"$text{'default'} (400)"), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'ui_height'},
	&ui_opt_textbox("height", $gconfig{'help_height'}, 5,
			"$text{'default'} (400)"), undef, [ "valign=middle","valign=middle" ]);

# Dialog box size options
print &ui_table_hr();

foreach $db ("file", "user", "users", "date", "module", "modules") {
	($w, $h) = split(/x/, $gconfig{'db_size'.$db});
	print &ui_table_row($text{'ui_size'.$db},
		&ui_radio("size".$db."_def", $w ? 0 : 1,
			[ [ 1, $text{'default'} ],
			  [ 0, &ui_textbox("size".$db."_w", $w, 4)." X ".
			       &ui_textbox("size".$db."_h", $h, 4) ] ]), undef, [ "valign=middle","valign=middle" ]);
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

