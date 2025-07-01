#!/usr/local/bin/perl
# Display debugging mode options

require './webmin-lib.pl';
&ui_print_header(undef, $text{'debug_title'}, "");

print &ui_form_start("change_debug.cgi", "post");
print &ui_table_start($text{'debug_header'}, undef, 2);

# Debugging mode enabled
print &ui_table_row($text{'debug_enabled'},
	&ui_yesno_radio("debug_enabled", $gconfig{'debug_enabled'}), undef, [ "valign=middle","valign=middle" ]);

# What to log
print &ui_table_row($text{'debug_what'},
	join("<br>\n",
	     map { &ui_checkbox('debug_what_'.$_, 1, $text{'debug_what_'.$_},
				$gconfig{'debug_what_'.$_}) }
		 @debug_what_events));

# Log to where
print &ui_table_row($text{'debug_file'},
	&ui_opt_textbox("debug_file", $gconfig{'debug_file'},
			50, $text{'default'}.
			    " (<tt>$main::default_debug_log_file</tt>)"), undef, [ "valign=middle","valign=middle" ]);

# Maximum size
print &ui_table_row($text{'debug_size'},
	&ui_radio("debug_size_def", $gconfig{'debug_size'} ? 0 : 1,
		  [ [ 1, $text{'default'}.
			 " (".&html_strip(&nice_size($main::default_debug_log_size)).")" ],
		    [ 0, &ui_bytesbox("debug_size", $gconfig{'debug_size'}) ] ]
		 ), undef, [ "valign=middle","valign=middle" ]);

# Debug background processes?
print &ui_table_row($text{'debug_procs'},
	&ui_checkbox("debug_web", 1, $text{'debug_web'},
		     !$gconfig{'debug_noweb'})."\n".
	&ui_checkbox("debug_cmd", 1, $text{'debug_cmd'},
		     !$gconfig{'debug_nocmd'})."\n".
	&ui_checkbox("debug_cron", 1, $text{'debug_cron'},
		     !$gconfig{'debug_nocron'}), undef, [ "valign=middle","valign=middle" ]);

# Modules to debug
# Modules to log in
print &ui_table_row($text{'debug_inmods'},
	&ui_radio("mall", $gconfig{'debug_modules'} ? 0 : 1,
		  [ [ 1, $text{'log_mall'} ], [ 0, $text{'log_modules'} ] ]).
	"<br>\n".
	&ui_select("modules", [ split(/\s+/, $gconfig{'debug_modules'}) ],
		   [ map { [ $_->{'dir'}, $_->{'desc'} ] }
			 sort { $a->{'desc'} cmp $b->{'desc'} }
			      &get_all_module_infos() ], 5, 1));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

