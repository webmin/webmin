#!/usr/local/bin/perl
# Display the advanced options form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'advanced_title'}, "");
&get_miniserv_config(\%miniserv);

print &ui_form_start("change_advanced.cgi", "post");
print &ui_table_start($text{'advanced_header'}, undef, 2);

# Global temp directory
print &ui_table_row($text{'advanced_temp'},
		    &ui_opt_textbox("tempdir", $gconfig{'tempdir'},
				    30, $text{'advanced_tempdef'}));

# Per-module temp directories
@mods = sort { $a->{'desc'} cmp $b->{'desc'} } &get_all_module_infos();
$ttable = &ui_columns_start([ $text{'advanced_tmod'},
			      $text{'advanced_tdir'} ]);
$i = 0;
foreach $d (&get_tempdirs(\%gconfig), [ ]) {
	$ttable .= &ui_columns_row([
		&ui_select("tmod_$i", $d->[0],
			[ [ "", "&nbsp;" ],
			  map { [ $_->{'dir'}, $_->{'desc'} ] } @mods ]),
		&ui_textbox("tdir_$i", $d->[1], 30)
		]);
	$i++;
	}
$ttable .= &ui_columns_end();
print &ui_table_row($text{'advanced_tempmods'}, $ttable);

@preloads = &get_preloads(\%miniserv);
if (!@preloads ||
    $preloads[0]->[0] eq "main" && $preloads[0]->[1] eq "web-lib-funcs.pl") {
	# Only show preload option if in supported mode
	print &ui_table_row($text{'advanced_preload'},
			    &ui_yesno_radio("preload", @preloads ? 1 : 0));
	}

# Show call stack on error
print &ui_table_row($text{'advanced_stack'},
		    &ui_yesno_radio("stack", int($gconfig{'error_stack'})));

# Show CGI errors
print &ui_table_row($text{'advanced_showstderr'},
	    &ui_yesno_radio("showstderr", int(!$miniserv{'noshowstderr'})));

# Pass passwords to CGI programs
print &ui_table_row($text{'advanced_pass'},
		    &ui_yesno_radio("pass", int($miniserv{'pass_password'})));

# Umask for created files
print &ui_table_row($text{'advanced_umask'},
	    &ui_opt_textbox("umask", $gconfig{'umask'}, 5, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

