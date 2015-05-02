#!/usr/local/bin/perl
# index.cgi
# Display a list of run-levels and the actions that are run at boot and
# shutdown time for each level

require './init-lib.pl';
require './hostconfig-lib.pl';
&ui_print_header(&text('index_mode', $text{'mode_'.$init_mode}),
		 $text{'index_title'}, "", undef, 1, 1);

if ($init_mode eq "osx" && $access{'bootup'}) {
	# This hostconfig if block written by Michael A Peters <mpeters@mac.com>
	# for OSX/Darwin.
	# build hostconfig table 
	
	@hconf_set = &hostconfig_settings();
	%description_list = &hostconfig_gather(description);
	
	print &ui_columns_start([ &text('index_action'),
				  &text('index_setting'),
				  &text('index_desc') ], 100, 0);
	$i = 0;
	while (<@hconf_set>) {
		$action_description = $description_list{"$hconf_set[$i][0]"};
		print &hostconfig_table($hconf_set[$i][0], $hconf_set[$i][1], $action_description);
		$i++;
		}
	print &ui_columns_end();
	if ($access{'bootup'} == 1) {
		print &ui_links_row([
            &ui_link("edit_hostconfig.cgi?1", $text{'index_add_mac'}),
            &ui_link("edit_hostconfig.cgi?2", &text('index_editconfig',"<tt>$config{'hostconfig'}</tt>") )
			]);
		}
	}
elsif ($init_mode eq "init" && $access{'bootup'}) {
	# build list of normal and broken actions
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		$nodemap{$ac[1]} = $ac[0];
		push(@acts, $ac[0]);
		push(@actsl, "0+".&urlize($ac[0]));
		push(@actsf, $ac[0] =~ /^\// ? $ac[0]
					     : "$config{'init_dir'}/$ac[0]");
		}
	@runlevels = &list_runlevels();
	foreach $r (@runlevels) {
		foreach $w ("S", "K") {
			foreach $a (&runlevel_actions($r, $w)) {
				@ac = split(/\s+/, $a);
				if (!$nodemap{$ac[2]}) {
					push(@acts, $ac[1]);
					push(@actsl,
					     "1+$r+$ac[0]+$ac[1]+$ac[2]+$w");
					push(@actsf, "$config{'init_base'}/rc$r.d/$w$ac[0]$ac[1]");
					}
				}
			}
		}

	# For each action, look at /etc/rc*.d/* files to see if it is 
	# started at boot
	@boot = &get_inittab_runlevel();
	for($i=0; $i<@acts; $i++) {
		foreach $s (&action_levels('S', $acts[$i])) {
			local ($l, $p) = split(/\s+/, $s);
			local ($lvl) = (&indexof($l, @boot) >= 0);
			local %daemon;
			if ($lvl && $config{'daemons_dir'} &&
			    &read_env_file("$config{'daemons_dir'}/$acts[$i]",
					   \%daemon)) {
				$lvl = lc($daemon{'ONBOOT'}) eq 'yes' ? 1 : 0;
				}
			push(@{$actsb[$i]}, [ $l, $p, $lvl ]);
			}
		@{$actsb[$i]} = sort { $b->[2] <=> $a->[2] } @{$actsb[$i]};
		}

	# Sort the actions if necessary
	@order = ( 0 .. $#acts );
	if ($config{'sort_mode'}) {
		@order = sort { local $aa = $actsb[$a]->[0];
				local $bb = $actsb[$b]->[0];
				$bb->[2] <=> $aa->[2] ||
				$bb->[1] <=> $aa->[1] }
			      @order;
		}
	@acts = map { $acts[$_] } @order;
	@actsl = map { $actsl[$_] } @order;
	@actsf = map { $actsf[$_] } @order;
	@actsb = map { $actsb[$_] } @order;

	@links = ( );
	if ($access{'bootup'} == 1) {
		push(@links, &ui_link("edit_action.cgi?2", $text{'index_add'}) );
		}
	if (!$config{'desc'}) {
		# Display actions by name only
		print &ui_links_row(\@links);
		@grid = ( );
		for($i=0; $i<@acts; $i++) {
			if ($acts[$i]) {
				push(@grid, &ui_link("edit_action.cgi?".$actsl[$i], $acts[$i]) );
				}
			}
		print &ui_grid_table(\@grid, 4, 100,
		     [ "width=25%", "width=25%", "width=25%", "width=25%" ],
		     undef, $text{'index_title'});
		print &ui_links_row(\@links);
		}
	else {
		# Display actions and descriptions
		print &ui_form_start("mass_start_stop.cgi", "post");
		print &ui_links_row(\@links);
		print &ui_columns_start([
			"",
			$text{'index_action'},
			$config{'desc'} == 2 ? $text{'index_levels'}
					     : $text{'index_boot'},
			$config{'order'} ? ( $text{'index_order'} ) : ( ),
			$config{'status_check'} == 2 ? ( $text{'index_status'} ) : ( ),
			$text{'index_desc'} ],
			100, 0, [ "", "nowrap", "nowrap", "nowrap", "nowrap" ]);

		for($i=0; $i<@acts; $i++) {
			local ($boot, %daemon, @levels, $order);
			foreach $s (@{$actsb[$i]}) {
				if ($s->[2]) {
					$boot = 1;
					push(@levels,
					  "<font color=#ff0000>$s->[0]</font>");
					}
				else {
					push(@levels, $s->[0]);
					}
				}
			$order = $actsb[$i]->[0]->[1];
			local @cols;
			push(@cols, &ui_link("edit_action.cgi?".$actsl[$i], $acts[$i]) );
			local %has;
			$d = &html_escape(&init_description($actsf[$i],
				 $config{'status_check'} == 2 ? \%has : undef));
			if ($config{'desc'} == 2) {
				push(@cols, join(" ", @levels));
				}
			else {
				push(@cols,$boot ? $text{'yes'} :
				      "<font color=#ff0000>$text{'no'}</font>");
				}
			if ($config{'order'}) {
				push(@cols, $order);
				}
			if ($config{'status_check'} == 2) {
				if ($actsl[$i] =~ /^0/ && $has{'status'}) {
					local $r = &action_running($actsf[$i]);
					if ($r == 0) {
						push(@cols,
							"<font color=#ff0000>".
							"$text{'no'}</font>");
						}
					elsif ($r == 1) {
						push(@cols, $text{'yes'});
						}
					else {
						push(@cols, undef);
						}
					}
				else {
					push(@cols, undef);
					}
				}
			push(@cols, $d);
			if ($actsl[$i] =~ /^0/) {
				print &ui_checked_columns_row(
					\@cols, undef, "idx", $order[$i]);
				}
			else {
				print &ui_columns_row([ undef, @cols ]);
				}
			}
		print &ui_columns_end();
		print &ui_links_row(\@links);
		@buts = ( [ "start", $text{'index_start'} ],
			  [ "stop", $text{'index_stop'} ],
			  [ "restart", $text{'index_restart'} ] );
		if ($access{'bootup'} == 1) {
			# Show buttons to enable/disable at boot
			push(@buts, undef,
			    [ "addboot", $text{'index_addboot'} ],
			    [ "delboot", $text{'index_delboot'} ],
			    undef,
			    [ "addboot_start", $text{'index_addboot_start'} ],
			    [ "delboot_stop", $text{'index_delboot_stop'} ],
			    );
			}
		print &ui_form_end(\@buts);
		}
	}
elsif ($init_mode eq "local" && $access{'bootup'} == 1) {
	# Display local bootup script
	if ($config{'hostconfig'}) {
		# This means a darwin system where
		# daemons are not started in the rc script
		print &text('index_script_mac',
			"<tt>$config{'local_script'}</tt>"),"<br>\n";
		}
	else {
		print &text('index_script',
			"<tt>$config{'local_script'}</tt>"),"<br>\n";
		}
	print &ui_form_start("save_local.cgi", "post");
	print &ui_textarea("local",
		&read_file_contents($config{'local_script'}), 15, 80)."<br>\n";

	# Show shutdown script too, if any
	if ($config{'local_down'}) {
		print &text('index_downscript',
			"<tt>$config{'local_down'}</tt>"),"<br>\n";
		print &ui_textarea("down",
			&read_file_contents($config{'local_down'}), 15, 80).
			"<br>\n";
		}

	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}
elsif ($init_mode eq "win32" && $access{'bootup'}) {
	# Show Windows services
	print &ui_form_start("save_services.cgi", "post");
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"<br>\n";
	print &ui_columns_start([ "", $text{'index_sname'},
				  $text{'index_sdesc'},
				  $text{'index_sboot'},
				  $text{'index_sstate'} ]);
	foreach $svc (&list_win32_services()) {
		print &ui_columns_row([
			&ui_checkbox("d", $svc->{'name'}, undef),
			$svc->{'name'},
			$svc->{'desc'},
			$text{'index_sboot'.$svc->{'boot'}} ||
			  $svc->{'boot_desc'},
			$text{'index_sstate'.$svc->{'state'}} ||
			  $svc->{'state_desc'},
			]);
		}
	print &ui_columns_end();
	print &select_all_link("d"),"\n";
	print &select_invert_link("d"),"<br>\n";
	print &ui_form_end([ [ "start", $text{'index_start'} ],
			     [ "stop", $text{'index_stop'} ],
			     undef,
			     [ "addboot", $text{'index_addboot'} ],
			     [ "delboot", $text{'index_delboot'} ],
			     undef,
			     [ "addboot_start", $text{'index_addboot_start'} ],
			     [ "delboot_stop", $text{'index_delboot_stop'} ],
			    ]);
	print &ui_hr();
	}
elsif ($init_mode eq "rc" && $access{'bootup'}) {
	# Show FreeBSD scripts
	print &ui_form_start("mass_rcs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_rc.cgi?new=1", $text{'index_radd'}) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_rname'},
				  $text{'index_rdesc'},
				  $text{'index_rboot'} ]);
	foreach $rc (&list_rc_scripts()) {
		print &ui_columns_row([
			&ui_checkbox("d", $rc->{'name'}, undef),
			&ui_link("edit_rc.cgi?name=".&urlize($rc->{'name'}), $rc->{'name'}),
			$rc->{'desc'},
			$rc->{'enabled'} == 1 ? $text{'yes'} :
			$rc->{'enabled'} == 2 ? "<i>$text{'index_unknown'}</i>":
				"<font color=#ff0000>$text{'no'}</font>",
			]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "start", $text{'index_start'} ],
			     [ "stop", $text{'index_stop'} ],
			     undef,
			     [ "addboot", $text{'index_addboot'} ],
			     [ "delboot", $text{'index_delboot'} ],
			     undef,
			     [ "addboot_start", $text{'index_addboot_start'} ],
			     [ "delboot_stop", $text{'index_delboot_stop'} ],
			    ]);
	}
elsif ($init_mode eq "upstart" && $access{'bootup'}) {
	# Show upstart actions
	print &ui_form_start("mass_upstarts.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_upstart.cgi?new=1", $text{'index_uadd'}) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_uname'},
				  $text{'index_udesc'},
				  $text{'index_uboot'},
				  $text{'index_ustatus'}, ]);
	foreach $u (&list_upstart_services()) {
		if ($u->{'legacy'}) {
			$l = "edit_action.cgi?0+".&urlize($u->{'name'});
			}
		else {
			$l = "edit_upstart.cgi?name=".&urlize($u->{'name'});
			}
		print &ui_columns_row([
			&ui_checkbox("d", $u->{'name'}, undef, 0),
            &ui_link($l, $u->{'name'}),
			$u->{'desc'},
			$u->{'boot'} eq 'start' ? $text{'yes'} :
			  $u->{'boot'} eq 'stop' ?
			  "<font color=#ff0000>$text{'no'}</font>" :
			  "<i>$text{'index_unknown'}</i>",
			$u->{'status'} eq 'running' ? $text{'yes'} :
			  $u->{'status'} eq 'waiting' ?
			  "<font color=#ff0000>$text{'no'}</font>" :
			  "<i>$text{'index_unknown'}</i>",
			]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "start", $text{'index_start'} ],
			     [ "stop", $text{'index_stop'} ],
			     [ "restart", $text{'index_restart'} ],
			     undef,
			     [ "addboot", $text{'index_addboot'} ],
			     [ "delboot", $text{'index_delboot'} ],
			     undef,
			     [ "addboot_start", $text{'index_addboot_start'} ],
			     [ "delboot_stop", $text{'index_delboot_stop'} ],
			    ]);

	}
elsif ($init_mode eq "systemd" && $access{'bootup'}) {
	# Show systemd actions
	print &ui_form_start("mass_systemd.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_systemd.cgi?new=1", $text{'index_sadd'}) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_uname'},
				  $text{'index_udesc'},
				  $text{'index_uboot'},
				  $text{'index_ustatus'}, ]);
	foreach $u (&list_systemd_services()) {
		if ($u->{'legacy'}) {
			$l = "edit_action.cgi?0+".&urlize($u->{'name'});
			}
		else {
			$l = "edit_systemd.cgi?name=".&urlize($u->{'name'});
			}
		print &ui_columns_row([
			&ui_checkbox("d", $u->{'name'}, undef),
			&ui_link($l, $u->{'name'}),
			$u->{'desc'},
			$u->{'boot'} == 1 ? $text{'yes'} :
			  $u->{'boot'} == 2 ? $text{'index_always'} :
			  "<font color=#ff0000>$text{'no'}</font>",
			$u->{'status'} ? $text{'yes'} :
			  "<font color=#ff0000>$text{'no'}</font>",
			]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "start", $text{'index_start'} ],
			     [ "stop", $text{'index_stop'} ],
			     [ "restart", $text{'index_restart'} ],
			     undef,
			     [ "addboot", $text{'index_addboot'} ],
			     [ "delboot", $text{'index_delboot'} ],
			     undef,
			     [ "addboot_start", $text{'index_addboot_start'} ],
			     [ "delboot_stop", $text{'index_delboot_stop'} ],
			    ]);

	}
elsif ($init_mode eq "launchd" && $access{'bootup'}) {
	# Show launchd agents
	print &ui_form_start("mass_launchd.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   &ui_link("edit_launchd.cgi?new=1", $text{'index_ladd'}) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_lname'},
				  $text{'index_uboot'},
				  $text{'index_ustatus'}, ]);
	foreach $u (&list_launchd_agents()) {
		$l = "edit_launchd.cgi?name=".&urlize($u->{'name'});
		print &ui_columns_row([
			&ui_checkbox("d", $u->{'name'}, undef),
			&ui_link($l, $u->{'name'}),
			$u->{'boot'} ? $text{'yes'} :
			  "<font color=#ff0000>$text{'no'}</font>",
			$u->{'status'} ? $text{'yes'} :
			  "<font color=#ff0000>$text{'no'}</font>",
			]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "start", $text{'index_start'} ],
			     [ "stop", $text{'index_stop'} ],
			     [ "restart", $text{'index_restart'} ],
			     undef,
			     [ "addboot", $text{'index_addboot'} ],
			     [ "delboot", $text{'index_delboot'} ],
			     undef,
			     [ "addboot_start", $text{'index_addboot_start'} ],
			     [ "delboot_stop", $text{'index_delboot_stop'} ],
			    ]);

	}

# reboot/shutdown buttons
print &ui_hr();
print &ui_buttons_start();
if ($init_mode eq 'init' && $access{'bootup'} == 1) {
	print &ui_buttons_row("change_rl.cgi", $text{'index_rlchange'},
			      $text{'index_rlchangedesc'}, undef,
			      &ui_select("level", $boot[0], \@runlevels));
	}
if ($access{'reboot'}) {
	print &ui_buttons_row("reboot.cgi", $text{'index_reboot'},
			      $text{'index_rebootmsg'});
	}
if ($access{'shutdown'}) {
	print &ui_buttons_row("shutdown.cgi", $text{'index_shutdown'},
			      $text{'index_shutdownmsg'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

