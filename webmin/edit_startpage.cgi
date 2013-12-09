#!/usr/local/bin/perl
# edit_startpage.cgi
# Startpage config form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'startpage_title'}, "");

print $text{'startpage_intro2'},"<p>\n";

print &ui_form_start("change_startpage.cgi", "post");
print &ui_table_start($text{'startpage_title'}, undef, 2);

print &ui_table_row($text{'startpage_nocol'},
	&ui_opt_textbox("nocols", $gconfig{'nocols'}, 5, $text{'default'}), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_tabs'},
	&ui_radio("notabs", $gconfig{'notabs'} ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]), undef, [ "valign=middle","valign=middle" ]);

@modules = &get_all_module_infos();
%cats = &list_categories(\@modules);
print &ui_table_row($text{'startpage_deftab'},
	&ui_select("deftab", $gconfig{'deftab'} || 'webmin',
		   [ map { [ $_, $cats{$_} ] }
			 sort { $cats{$a} cmp $cats{$b} } (keys %cats) ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_nohost'},
	&ui_radio("nohostname", $gconfig{'nohostname'} ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_gotoone'},
	&ui_yesno_radio("gotoone", int($gconfig{'gotoone'})), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_gotomodule'},
	&ui_select("gotomodule", $gconfig{'gotomodule'},
		[ [ "", $text{'startpage_gotonone'} ],
		  map { [ $_->{'dir'}, $_->{'desc'} ] }
		      sort { $a->{'desc'} cmp $b->{'desc'} } @modules ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_webminup'},
	&ui_yesno_radio("webminup", !$gconfig{'nowebminup'}), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_row($text{'startpage_moduleup'},
	&ui_yesno_radio("moduleup", !$gconfig{'nomoduleup'}), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

