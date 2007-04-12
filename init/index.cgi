#!/usr/local/bin/perl
# index.cgi
# Display a list of run-levels and the actions that are run at boot and
# shutdown time for each level

require './init-lib.pl';
require './hostconfig-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
%access = &get_module_acl();

if ($init_mode eq "osx" && $access{'bootup'}) {
	# This hostconfig if block written by Michael A Peters <mpeters@mac.com>
	# for OSX/Darwin.
	# build hostconfig table 
	
	@hconf_set = &hostconfig_settings();
	%description_list = &hostconfig_gather(description);
	
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>", &text('index_action'), "</b></td>\n";
	print "<td><b>", &text('index_setting'), "</b></td>\n";
	print "<td> <b>", &text('index_desc'), "</b></td> </tr>\n";
	$i = 0;
	while (<@hconf_set>) {
		$action_description = $description_list{"$hconf_set[$i][0]"};
		print &hostconfig_table($hconf_set[$i][0], $hconf_set[$i][1], $action_description);
		$i++;
		}
	print "</table>\n";
	if ($access{'bootup'} == 1) {
		print "<a href='edit_hostconfig.cgi?1'>$text{'index_add_mac'}</a><br>\n";
		print "<a href='edit_hostconfig.cgi?2'>", &text('index_editconfig',
			"<tt>$config{'hostconfig'}</tt>"),"</a><P>\n";
		}
	print "<hr>\n"; 
	}
elsif ($init_mode eq "init" && $access{'bootup'}) {
	# build list of normal and broken actions
	@iacts = &list_actions();
	foreach $a (@iacts) {
		@ac = split(/\s+/, $a);
		$nodemap{$ac[1]} = $ac[0];
		push(@acts, $ac[0]);
		push(@actsl, "0+$ac[0]");
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
		push(@links,
			"<a href='edit_action.cgi?2'>$text{'index_add'}</a>");
		}
	print &ui_links_row(\@links);
	if (!$config{'desc'}) {
		# Display actions by name only
		print "<table width=100% border>\n";
		print "<tr $tb> <td><b>$text{'index_title'}</b></td> </tr>\n";
		print "<tr $cb> <td><table width=100%>\n";
		$len = @acts; $len = int(($len+3)/4)*4;
		for($i=0; $i<$len; $i++) {
			if ($i%4 == 0) { print "<tr>\n"; }
			print "<td width=25%>";
			if ($acts[$i]) {
				print "<a href=\"edit_action.cgi?$actsl[$i]\">",
				      "$acts[$i]</a>\n";
				}
			print "</td>\n";
			if ($i%4 == 3) { print "</tr>\n"; }
			}
		print "</table></td></tr></table>\n";
		}
	else {
		# Display actions and descriptions
		print &ui_form_start("mass_start_stop.cgi", "post");
		print &ui_columns_start([
			"",
			$text{'index_action'},
			$config{'desc'} == 2 ? $text{'index_levels'}
					     : $text{'index_boot'},
			$config{'order'} ? ( $text{'index_order'} ) : ( ),
			$config{'status_check'} == 2 ? ( $text{'index_status'} ) : ( ),
			$text{'index_desc'} ],
			100);

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
			push(@cols, "<a href=\"edit_action.cgi?".
			      	    "$actsl[$i]\">$acts[$i]</a>");
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
				if ($actsl[$i] =~ /^0/) {
					local $out = $has{'status'} ?
						`$actsf[$i] status` : '';
					if ($out =~ /running/i) {
						push(@cols, $text{'yes'});
						}
					elsif ($out =~ /stopped/i) {
						push(@cols,
							"<font color=#ff0000>".
							"$text{'no'}</font>");
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
				print &ui_columns_row(\@cols);
				}
			}
		print &ui_columns_end();
		print "<input type=submit name=start value='$text{'index_start'}'>\n";
		print "<input type=submit name=stop value='$text{'index_stop'}'>\n";
		print "<input type=submit name=restart value='$text{'index_restart'}'>\n";
		if ($access{'bootup'} == 1) {
			# Show buttons to enable/disable at boot
			print "&nbsp;&nbsp;\n";
			print "<input type=submit name=addboot value='$text{'index_addboot'}'>\n";
			print "<input type=submit name=delboot value='$text{'index_delboot'}'>\n";
			print "&nbsp;&nbsp;\n";
			print "<input type=submit name=addboot_start value='$text{'index_addboot_start'}'>\n";
			print "<input type=submit name=delboot_stop value='$text{'index_delboot_stop'}'>\n";
			}
		}
	print "</form>\n";
	print &ui_links_row(\@links);
	print "<hr>\n";

	if ($access{'bootup'} == 1) {
		# Show runlevel switch form
		print "<form action=change_rl.cgi>\n";
		print "<table width=100%>\n";

		print "<tr> <td nowrap><input type=submit ",
		      "value='$text{'index_rlchange'}'>\n";
		print "<select name=level>\n";
		foreach $r (@runlevels) {
			printf "<option %s>%s\n",
				$r eq $boot[0] ? "selected" : "", $r;
			}
		print "</select></td> <td>$text{'index_rlchangedesc'}</td> </tr>\n";

		print "</table></form><hr>\n";
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
	print "<form action=save_local.cgi method=post>\n";
	print "<textarea name=local rows=15 cols=80>";
	open(LOCAL, $config{'local_script'});
	while(<LOCAL>) { print &html_escape($_) }
	close(LOCAL);
	print "</textarea><br>\n";

	if ($config{'local_down'}) {
		# Show shutdown script too
		print &text('index_downscript',
			"<tt>$config{'local_down'}</tt>"),"<br>\n";
		print "<textarea name=down rows=15 cols=80>";
		open(LOCAL, $config{'local_down'});
		while(<LOCAL>) { print &html_escape($_) }
		close(LOCAL);
		print "</textarea><br>\n";
		}

	print "<input type=submit value='$text{'save'}'></form>\n";
	print "<hr>\n";
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
	print "<hr>\n";
	}
elsif ($init_mode eq "rc" && $access{'bootup'}) {
	# Show FreeBSD scripts
	print &ui_form_start("mass_rcs.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   "<a href='edit_rc.cgi?new=1'>$text{'index_radd'}</a>" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'index_rname'},
				  $text{'index_rdesc'},
				  $text{'index_rboot'} ]);
	foreach $rc (&list_rc_scripts()) {
		print &ui_columns_row([
			&ui_checkbox("d", $rc->{'name'}, undef),
			"<a href='edit_rc.cgi?name=".
			  &urlize($rc->{'name'})."'>$rc->{'name'}</a>",
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
	print "<hr>\n";

	}

# reboot/shutdown buttons
print "<table cellpadding=5 width=100%>\n";
if ($access{'reboot'}) {
	print "<form action=reboot.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value=\"$text{'index_reboot'}\"></td>\n";
	print "</form>\n";
	print "<td>$text{'index_rebootmsg'}</td> </tr>\n";
	}

if ($access{'shutdown'}) {
	print "<form action=shutdown.cgi>\n";
	print "<tr> <td><input type=submit ",
	      "value=\"$text{'index_shutdown'}\"></td>\n";
	print "</form>\n";
	print "<td>$text{'index_shutdownmsg'}</td> </tr>\n";
	}
print "</table>\n";

&ui_print_footer("/", $text{'index'});

