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
				    30, $text{'advanced_tempdef'})."<br>".
		    &ui_checkbox("tempdirdelete", 1, $text{'advanced_tdd'},
				 $gconfig{'tempdirdelete'}));

# Temp files clearing period
print &ui_table_row($text{'advanced_tempdelete'},
		    &ui_opt_textbox("tempdelete", $gconfig{'tempdelete_days'},
				    5, $text{'advanced_nodelete'})." ".
		    $text{'advanced_days'});

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
if (!@preloads && (!$miniserv{'premodules'} ||
		   $miniserv{'premodules'} eq 'WebminCore')) {
	# New-style preload possible or enabled
	print &ui_table_row($text{'advanced_preload'},
		    &ui_yesno_radio("preload",
				    $miniserv{'premodules'} eq 'WebminCore'));
	}
elsif ($preloads[0]->[0] eq "main" && $preloads[0]->[1] eq "web-lib-funcs.pl") {
	# Old-style preloads enabled
	print &ui_table_row($text{'advanced_preload'},
			    &ui_yesno_radio("preload", 1));
	}

# Files to pre-cache
$mode = $miniserv{'precache'} eq 'none' ? 0 :
        $miniserv{'precache'} eq '' ? 1 : 2;
print &ui_table_row($text{'advanced_precache'},
	&ui_radio("precache_mode", $mode,
		  [ [ 0, $text{'advanced_precache0'}."<br>" ],
		    [ 1, $text{'advanced_precache1'}."<br>" ],
		    [ 2, &text('advanced_precache2',
			  &ui_textbox("precache",
			   $mode == 2 ? $miniserv{'precache'} : "", 40)) ] ]));

# Umask for created files
print &ui_table_row($text{'advanced_umask'},
	    &ui_opt_textbox("umask", $gconfig{'umask'}, 5, $text{'default'}));

# Overwrite immutable files
if (&has_command("chattr")) {
	print &ui_table_row($text{'advanced_chattr'},
		    &ui_yesno_radio("chattr", $gconfig{'chattr'}));
	}

# Network buffer size
print &ui_table_row($text{'advanced_bufsize'},
	&ui_opt_textbox("bufsize", $miniserv{'bufsize'}, 6,
			$text{'default'}." (32768)"));

# Network download buffer size
print &ui_table_row($text{'advanced_bufsize_binary'},
	&ui_opt_textbox("bufsize_binary", $miniserv{'bufsize_binary'}, 6,
			$text{'default'}." (1048576)"));

# Nice level for cron jobs
if (&foreign_check("proc")) {
	&foreign_require("proc", "proc-lib.pl");
	print &ui_table_row($text{'advanced_nice'},
	    &ui_radio("nice_def", $gconfig{'nice'} eq '' ? 1 : 0,
	      [ [ 1, $text{'default'} ],
		[ 0, $text{'advanced_pri'}." ".
		     &proc::nice_selector("nice", $gconfig{'nice'} || 0) ] ]));

	# IO scheduling class and priority
	if (defined(&proc::os_list_scheduling_classes) &&
	    (@classes = &proc::os_list_scheduling_classes())) {
		print &ui_table_row($text{'advanced_sclass'},
			&ui_select("sclass", $gconfig{'sclass'},
				   [ [ undef, $text{'default'} ],
				     @classes ]));

		@prios = &proc::os_list_scheduling_priorities();
		print &ui_table_row($text{'advanced_sprio'},
			&ui_select("sprio", $gconfig{'sprio'},
				   [ [ undef, $text{'default'} ],
				     @prios ]));
		}
	}

# Extra HTTP headers
print &ui_table_row($text{'advanced_headers'},
	&ui_textarea("headers",
		join("\n", split(/\t/, $gconfig{'extra_headers'})), 5, 80));

# Sort config file's keys alphabetically
print &ui_table_row($text{'advanced_sortconfigs'},
	&ui_yesno_radio("sortconfigs", $gconfig{'sortconfigs'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

