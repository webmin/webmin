#!/usr/local/bin/perl
# Show the web serving options form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'web_title'}, "");
&get_miniserv_config(\%miniserv);

print &ui_form_start("change_web.cgi", "post");
print &ui_table_start($text{'web_header'}, undef, 2);

# Default content expiry time
print &ui_table_row($text{'web_expires'},
	&ui_opt_textbox("expires", $miniserv{'expires'}, 10,
			$text{'web_expiresdef'}, $text{'web_expiressecs'}));

# Show call stack on error
print &ui_table_row($text{'advanced_stack'},
		    &ui_yesno_radio("stack", int($gconfig{'error_stack'})));

# Show CGI errors
print &ui_table_row($text{'advanced_showstderr'},
	    &ui_yesno_radio("showstderr", int(!$miniserv{'noshowstderr'})));

if (!$miniserv{'session'}) {
	# Pass passwords to CGI programs
	print &ui_table_row($text{'advanced_pass'},
		    &ui_yesno_radio("pass", int($miniserv{'pass_password'})));
	}

# Gzip static files?
print &ui_table_row($text{'advanced_gzip'},
	&ui_radio("gzip", $miniserv{'gzip'},
		  [ [ '', $text{'advanced_gzipauto'} ],
		    [ 0, $text{'advanced_gzip0'} ],
		    [ 1, $text{'advanced_gzip1'} ] ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

