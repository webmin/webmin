#!/usr/local/bin/perl
# edit_action.cgi
# Edit or create a bootup action. Existing actions can either be in the
# init.d directory (and linked to from the appropriate runlevels), or
# just plain runlevel files

require './init-lib.pl';
$access{'bootup'} || &error($text{'edit_ecannot'});

$ty = $ARGV[0];
if ($ty == 0) {
	# Editing an action in init.d, linked to from various runlevels
	$ac = $ARGV[1];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$file = &action_filename($ac);
	$data = &read_file_contents($file);
	$hasarg = &get_action_args($file);
	}
elsif ($ty == 1) {
	# Editing an action in one of the runlevels
	$rl = $ARGV[1];
	$num = $ARGV[2];
	$ac = $ARGV[3];
	$inode = $ARGV[4];
	$ss = $ARGV[5];
	&ui_print_header(undef, $text{'edit_title'}, "");
	$file = &runlevel_filename($rl, $ss, $num, $ac);
	$data = &read_file_contents($file);
	}
else {
	# Creating a new action in init.d
	&ui_print_header(undef, $text{'create_title'}, "");
	}

print &ui_form_start("save_action.cgi", "form-data");
print &ui_table_start($text{'edit_details'}, "width=100%", 2);
print &ui_hidden("type", $ty);

if ($ty != 2) {
	print &ui_hidden("old", $ac);
	print &ui_hidden("file", $file);
	if ($ty == 1) {
		print &ui_hidden("runlevel", $rl);
		print &ui_hidden("startstop", $ss);
		print &ui_hidden("number", $num);
		}
	}

# Action name
if ($ac =~ /^\// || $access{'bootup'} == 2) {
	print &ui_table_row($text{'edit_name'}, "<tt>$ac</tt>");
	print &ui_hidden("name", $ac);
	print &ui_hidden("extra", 1);
	}
else {
	print &ui_table_row($text{'edit_name'},
			    &ui_textbox("name", $ac, 30));
	}

if ($ty == 2) {
	# Display fields for a template for a new action
	print &ui_table_row($text{'edit_desc'},
		&ui_textarea("desc", undef, 2, 80));

	if ($config{'start_stop_msg'}) {
		print &ui_table_row($text{'edit_startmsg'},
			&ui_textbox("start_msg", undef, 40));

		print &ui_table_row($text{'edit_stopmsg'},
			&ui_textbox("stop_msg", undef, 40));
		}

	print &ui_table_row($text{'edit_start'},
		&ui_textarea("start", undef, 5, 80));

	print &ui_table_row($text{'edit_stop'},
		&ui_textarea("stop", undef, 5, 80));
	}
elsif ($access{'bootup'} == 2) {
	# Just show current script
	print &ui_table_row($text{'edit_script'},
		&ui_textarea("data", $data, 15, 80, undef, undef,
			     "readonly=true"));
	}
else {
	# Allow direct editing of the script
	print &ui_table_row($text{'edit_script'},
		&ui_textarea("data", $data, 15, 80));
	}

if ($ty == 1 && $access{'bootup'} == 1) {
	# Display a message about the script being bogus
	print &ui_table_end();
	print "<b>",&text("edit_bad$ss", $rl),"</b><br>\n";
	print &ui_link("fix_action.cgi?$rl+$ss+$num+$ac", $text{'edit_fix'});
	print "<p>\n";
	}
elsif (!$config{'expert'} || $access{'bootup'} == 2) {
	# Just tell the user if this action is started at boot time
	local $boot = 0;
	if ($ty == 0) {
		local @boot = &get_inittab_runlevel();
		foreach $s (&action_levels('S', $ac)) {
			local ($l, $p) = split(/\s+/, $s);
			$boot = 1 if (&indexof($l, @boot) >= 0);
			}
		if ($boot && $config{'daemons_dir'} &&
		    &read_env_file("$config{'daemons_dir'}/$ac", \%daemon)) {
			$boot = lc($daemon{'ONBOOT'}) eq 'yes' ? 1 : 0;
			}
		print &ui_hidden("oldboot", $boot);
		}
	if ($access{'bootup'} == 1) {
		print &ui_table_row($text{'edit_boot'},
			&ui_yesno_radio("boot", $boot || $ty == 2 ? 1 : 0));
		}
	else {
		print &ui_table_row($text{'edit_boot'},
			$boot || $ty == 2 ? $text{'yes'} : $text{'no'});
		}

	# Show if action is currently running
	if ($hasarg->{'status'} && $config{'status_check'}) {
		$r = &action_running($file);
		if ($r == 0) {
			$status = "<font color=#ff0000>$text{'no'}</font>";
			}
		elsif ($r == 1) {
			$status = $text{'yes'};
			}
		else {
			$status = "<i>$text{'edit_unknown'}</i>";
			}
		print &ui_table_row($text{'edit_status'}, $status);
		}
	print &ui_table_end();
	}
else {
	if ($config{'daemons_dir'} && $ac &&
	    &read_env_file("$config{'daemons_dir'}/$ac", \%daemon)) {
		# Display onboot flag from daemons file
		$boot = lc($daemon{'ONBOOT'}) eq 'yes';
		print &ui_table_row($text{'edit_boot'},
			&ui_yesno_radio("boot", $boot ? 1 : 0));
		}
	print &ui_table_end();

	# Display which runlevels the action is started/stopped in
	print &ui_table_start($text{'edit_levels'}, "width=100%", 4);
	if ($ac) {
		foreach $s (&action_levels('S', $ac)) {
			@s = split(/\s+/, $s);
			$spri{$s[0]} = $s[1];
			}
		foreach $k (&action_levels('K', $ac)) {
			@k = split(/\s+/, $k);
			$kpri{$k[0]} = $k[1];
			}
		}
	@boot = &get_inittab_runlevel();
	foreach $rl (&list_runlevels()) {
		if (&indexof($rl, @boot) == -1) {
			$label = &text('edit_rl', $rl);
			}
		else {
			$label = "<i>".&text('edit_rl', $rl)."</i>";
			}

		$od = $config{'order_digits'};
		$msg = &ui_checkbox("S$rl", 1, $text{'edit_startat'},
				    defined($spri{$rl}))." ".
		       &ui_textbox("pri_S$rl", $spri{$rl}, $od)."\n".
		       &ui_checkbox("K$rl", 1, $text{'edit_stopat'},
				    defined($kpri{$rl}))." ".
		       &ui_textbox("pri_K$rl", $kpri{$rl}, $od);
		print &ui_table_row($label, $msg);
		}
	print &ui_table_end();
	}

if ($ty != 2) {
	if ($access{'bootup'} == 1) {
		push(@buts, [ undef, $text{'save'} ]);
		}

	# Buttons to start and stop
	$args = join("+", @ARGV);
	print &ui_hidden("back", "edit_action.cgi?$args");
	foreach $a (@action_buttons) {
		if ($a eq 'start' || $a eq 'stop' || $hasarg->{$a}) {
			push(@buts, [ $a, $text{'edit_'.$a.'now'} ]);
			}
		}

	# Button to delete
	if ($access{'bootup'} == 1) {
		push(@buts, [ "delete", $text{'delete'} ]);
		}
	print &ui_form_end(\@buts);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});


