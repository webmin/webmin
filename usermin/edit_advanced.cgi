#!/usr/local/bin/perl
# Display the advanced options form

require './usermin-lib.pl';
&ui_print_header(undef, $text{'advanced_title'}, "");
&get_usermin_miniserv_config(\%miniserv);
&get_usermin_config(\%uconfig);

print &ui_form_start("change_advanced.cgi", "post");
print &ui_table_start($webmin::text{'advanced_header'}, undef, 2);

# Global temp directory
print &ui_table_row($webmin::text{'advanced_temp'},
		    &ui_opt_textbox("tempdir", $uconfig{'tempdir'},
				    30, $webmin::text{'advanced_tempdef'}));

# Per-module temp directories
@mods = sort { $a->{'desc'} cmp $b->{'desc'} } &list_modules();
$ttable = &ui_columns_start([ $webmin::text{'advanced_tmod'},
			      $webmin::text{'advanced_tdir'} ]);
$i = 0;
foreach $d (&webmin::get_tempdirs(\%uconfig), [ ]) {
	$ttable .= &ui_columns_row([
		&ui_select("tmod_$i", $d->[0],
			[ [ "", "&nbsp;" ],
			  map { [ $_->{'dir'}, $_->{'desc'} ] } @mods ]),
		&ui_textbox("tdir_$i", $d->[1], 30)
		]);
	$i++;
	}
$ttable .= &ui_columns_end();
print &ui_table_row($webmin::text{'advanced_tempmods'}, $ttable);

# Show call stack on error
print &ui_table_row($webmin::text{'advanced_stack'},
		    &ui_yesno_radio("stack", int($uconfig{'error_stack'})));

# Pass passwords to CGI programs
print &ui_table_row($text{'advanced_pass'},
		    &ui_yesno_radio("pass", int($miniserv{'pass_password'})));

# Umask for created files
print &ui_table_row($webmin::text{'advanced_umask'},
	    &ui_opt_textbox("umask", $uconfig{'umask'}, 5, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

