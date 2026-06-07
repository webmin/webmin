#!/usr/local/bin/perl
# index.cgi
# Display a list of run-levels and the actions that are run at boot and
# shutdown time for each level

require './init-lib.pl';
require './hostconfig-lib.pl';
&ReadParse();

# Save detected mode before rendering, so module.info can use mode-specific desc
&save_init_mode()
	if (!-r $init_mode_file && !&is_readonly_mode());

# Show the page title with the detected boot system name
&ui_print_header(&text('index_mode', &index_boot_system_title()),
		 $text{"index_title_$init_mode"} || $text{'index_title'},
		 "", undef, 1, 1);

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
					push(@levels, &ui_text_color($s->[0], 'warn'));
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
				push(@cols,$boot ? &ui_text_color("$text{'yes'}", 'success') :
				      &ui_text_color("$text{'no'}", 'warn'));
				}
			if ($config{'order'}) {
				push(@cols, $order);
				}
			if ($config{'status_check'} == 2) {
				if ($actsl[$i] =~ /^0/ && $has{'status'}) {
					local $r = &action_running($actsf[$i]);
					if ($r == 0) {
						push(@cols, &ui_text_color("$text{'no'}", 'warn'));
						}
					elsif ($r == 1) {
						push(@cols, &ui_text_color("$text{'yes'}", 'success'));
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
			&html_escape($svc->{'name'}),
			&html_escape($svc->{'desc'}),
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
			&ui_link("edit_rc.cgi?name=".&urlize($rc->{'name'}),
				 &html_escape($rc->{'name'})),
			&html_escape($rc->{'desc'}),
			$rc->{'enabled'} == 1 ? &ui_text_color("$text{'yes'}", 'success') :
			$rc->{'enabled'} == 2 ? "<i>$text{'index_unknown'}</i>":
				&ui_text_color("$text{'no'}", 'warn'),
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
			&ui_link($l, &html_escape($u->{'name'})),
			&html_escape($u->{'desc'}),
			$u->{'boot'} eq 'start' ? &ui_text_color("$text{'yes'}", 'success') :
			  $u->{'boot'} eq 'stop' ?
			  &ui_text_color("$text{'no'}", 'warn') :
			  "<i>$text{'index_unknown'}</i>",
			$u->{'status'} eq 'running' ? &ui_text_color("$text{'yes'}", 'success') :
			  $u->{'status'} eq 'waiting' ?
			  &ui_text_color("$text{'no'}", 'warn') :
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
	# Show systemd units by type; keep user units on their own tab.
	# Query parameters only choose the tab and optional user context.
	print &systemd_index_style();
	my $scope = $in{'scope'} eq 'user' ? 'user' : '';
	my $unituser = &clean_systemd_unit_value($in{'unituser'});
	my $unituser_details = $unituser ?
		&get_systemd_user_details($unituser) : undef;
	if ($scope eq 'user') {
		$unituser_details || &error($text{'systemd_euser'});
		}
	$unituser = "" if (!$unituser_details);
	my @systemd_units = &list_systemd_services();
	my @user_units = &list_all_systemd_user_services();
	my @tabs = &systemd_index_tabs(\@systemd_units, \@user_units, $unituser);
	my %valid_tabs = map { $_->{'id'}, 1 } @tabs;
	my $requested = defined($in{'mode'}) ? $in{'mode'} : "";
	my $mode = $requested && $valid_tabs{$requested} ? $requested :
		   $scope eq 'user' && $valid_tabs{'user'} ? 'user' :
		   $tabs[0]->{'id'};
	my $formno = 0;

	if (@tabs > 1) {
		my @uitabs = map { [ $_->{'id'}, $_->{'title'} ] } @tabs;
		print &ui_tabs_start(\@uitabs, "mode", $mode, 1);
		foreach my $tab (@tabs) {
			print &ui_tabs_start_tab("mode", $tab->{'id'});
			&print_systemd_index_tab($tab, $formno++);
			print &ui_tabs_end_tab("mode", $tab->{'id'});
			}
		print &ui_tabs_end(1);
		}
	else {
		&print_systemd_index_tab($tabs[0], $formno);
		}
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
			$u->{'boot'} ? &ui_text_color("$text{'yes'}", 'success') :
			  &ui_text_color("$text{'no'}", 'warn'),
			$u->{'status'} ? &ui_text_color("$text{'yes'}", 'success') :
			  &ui_text_color("$text{'no'}", 'warn'),
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

# index_boot_system_title()
# Returns the boot-system label shown in the page header.  For systemd
# systems, prefer the exact systemctl version string so the title reflects
# what is installed on the host.
sub index_boot_system_title
{
return $text{'mode_'.$init_mode} if ($init_mode ne "systemd");
my $systemctl = &has_command("systemctl");
return $text{'mode_systemd'} if (!$systemctl);

my $out = &backquote_command(quotemeta($systemctl)." --version 2>/dev/null");
return $text{'mode_systemd'} if ($?);
return $text{'mode_systemd'} if (!defined($out) || $out eq "");
my ($first) = split(/\r?\n/, $out, 2);
$first = &clean_systemd_unit_value($first);
return $first || $text{'mode_systemd'};
}

# systemd_index_style()
# Returns CSS used by the systemd index fragment.
sub systemd_index_style
{
return &ui_tag('style',
	".systemd_linger_toggle { text-decoration: none; }\n".
	".systemd_linger_toggle .ui_text_color { border-bottom: 1px dotted currentColor; }\n",
	{ 'type' => 'text/css' });
}

# systemd_index_tabs(&system-units, &user-units, [user])
# Builds the tab metadata for the systemd index, keeping system unit types
# separate and grouping all user-owned units into a dedicated tab.
sub systemd_index_tabs
{
my ($system_units, $user_units, $unituser) = @_;
my %by_type;
foreach my $u (@$system_units) {
	my ($display, $type) = &systemd_index_name_type($u->{'name'});
	$type = 'service' if ($u->{'legacy'} || !$type);
	next if (&indexof($type, &get_systemd_list_unit_types()) < 0);
	$u->{'_systemd_display'} = $display;
	$u->{'_systemd_type'} = $type;
	push(@{$by_type{$type}}, $u);
	}

my @tabs;
foreach my $type (&get_systemd_list_unit_types()) {
	my $units = $by_type{$type} || [ ];
	next if (!@$units);
	push(@tabs, { 'id' => $type,
		      'type' => $type,
		      'title' => &systemd_index_tab_title($type),
		      'desc' => &systemd_index_tab_desc($type),
		      'units' => $units });
	}

foreach my $u (@$user_units) {
	my ($display, $type) = &systemd_index_name_type($u->{'name'});
	$u->{'_systemd_display'} = $display;
	$u->{'_systemd_type'} = $type || 'service';
	}
if (@$user_units || $unituser) {
	push(@tabs, { 'id' => 'user',
		      'user' => 1,
		      'unituser' => $unituser,
		      'title' => $text{'systemd_tab_user'},
		      'desc' => $text{'systemd_tabdesc_user'},
		      'units' => $user_units });
	}

if (!@tabs) {
	push(@tabs, { 'id' => 'service',
		      'type' => 'service',
		      'title' => &systemd_index_tab_title('service'),
		      'desc' => &systemd_index_tab_desc('service'),
		      'units' => [ ] });
	}
return @tabs;
}

# print_systemd_index_tab(&tab, form-number)
# Outputs one systemd tab description and its mass-action table.
sub print_systemd_index_tab
{
my ($tab, $formno) = @_;
my $user_tab = $tab->{'user'} ? 1 : 0;
my %linger_cache;
my $create_url = $user_tab && $tab->{'unituser'} ?
	"edit_systemd.cgi?new=1&scope=user&unittype=service&unituser=".
	&urlize($tab->{'unituser'}) :
	$user_tab ? "edit_systemd.cgi?new=1&scope=user&unittype=service" :
	"edit_systemd.cgi?new=1&unittype=".&urlize($tab->{'type'} || 'service');
my @links = ( &select_all_link("d", $formno),
	      &select_invert_link("d", $formno),
	      &ui_link($create_url, $text{'index_sadd'}) );

print &ui_div($tab->{'desc'});
print &ui_form_start("mass_systemd.cgi", "post");
print &ui_links_row(\@links);
print &ui_hidden("scope", "users") if ($user_tab);

my @heads = ( "" );
push(@heads, $text{'systemd_name'});
push(@heads, $text{'systemd_desc'}) if ($config{'desc'});
push(@heads, $text{'systemd_type'}) if ($user_tab);
push(@heads, $text{'systemd_status'}, $text{'systemd_boot'},
	     $text{'index_ustatus'});
push(@heads, $text{'systemd_owner'}, $text{'systemd_linger_status'})
	if ($user_tab);
print &ui_columns_start(\@heads);
foreach my $u (@{$tab->{'units'}}) {
	my $link = $user_tab ?
		"edit_systemd.cgi?scope=user&unituser=".&urlize($u->{'user'}).
		"&name=".&urlize($u->{'name'}) :
		$u->{'legacy'} ? "edit_action.cgi?0+".&urlize($u->{'name'}) :
		"edit_systemd.cgi?name=".&urlize($u->{'name'});
	my $title = (defined($u->{'boot'}) && $u->{'boot'} == -1 ?
		     &html_escape($u->{'_systemd_display'}) :
		     &ui_link($link, &html_escape($u->{'_systemd_display'})));
	my $checkvalue = $user_tab ?
		&systemd_user_unit_selection_value($u->{'user'}, $u->{'name'}) :
		$u->{'name'};
	my @row = ( &ui_checkbox("d", $checkvalue, undef) );
	push(@row, $title);
	push(@row, &html_escape($u->{'desc'})) if ($config{'desc'});
	push(@row, &html_escape(&systemd_index_unit_type_title(
			$u->{'_systemd_type'}))) if ($user_tab);
	push(@row,
	     $u->{'fullstatus'} || &ui_tag('i', $text{'index_unknown'}),
	     &systemd_index_boot_column($u),
	     &systemd_index_status_column($u));
	if ($user_tab) {
		if (!exists($linger_cache{$u->{'user'}})) {
			$linger_cache{$u->{'user'}} =
				&systemd_user_linger_enabled($u->{'user'});
			}
		push(@row, &ui_tag('tt', &html_escape($u->{'user'})),
		     &systemd_linger_toggle_link(
			$u->{'user'}, $linger_cache{$u->{'user'}}));
		}
	print &ui_columns_row(\@row);
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

# systemd_index_name_type(unit-name)
# Splits a full unit name into display name and unit type.
sub systemd_index_name_type
{
my ($name) = @_;
my $units_piped = join('|', map { quotemeta } &get_systemd_unit_types());
my ($type) = $name =~ /\.([^.]+)$/;
if (defined($type) && $type =~ /^(?:$units_piped)$/) {
	my $display = $name;
	$display =~ s/\.$type$//;
	return ($display, $type);
	}
return ($name, "");
}

# systemd_index_tab_title(type)
# Returns the plural tab title for a systemd unit type.
sub systemd_index_tab_title
{
my ($type) = @_;
return $text{'systemd_tab_'.$type} ||
       $text{'systemd_type_'.$type} ||
       ucfirst($type);
}

# systemd_index_tab_desc(type)
# Returns the explanatory text shown under a systemd unit tab.
sub systemd_index_tab_desc
{
my ($type) = @_;
return $text{'systemd_tabdesc_'.$type} || "";
}

# systemd_index_unit_type_title(type)
# Returns the display label for a single unit type.
sub systemd_index_unit_type_title
{
my ($type) = @_;
return $text{'systemd_type_'.$type} || $type;
}

# systemd_user_unit_selection_value(user, unit)
# Encodes a user-unit owner and name into one checkbox value for mass actions.
sub systemd_user_unit_selection_value
{
my ($user, $unit) = @_;
return &urlize($user)."\t".&urlize($unit);
}

# systemd_linger_toggle_link(user, enabled)
# Returns a link to toggle linger for a user-unit owner.
sub systemd_linger_toggle_link
{
my ($user, $enabled) = @_;
my $target = $enabled ? 0 : 1;
my $label = $enabled ? $text{'yes'} : $text{'no'};
my $type = $enabled ? 'success' : 'warn';
my $title = $enabled ? &text('systemd_linger_disable', $user) :
		       &text('systemd_linger_enable', $user);
my $url = "set_systemd_linger.cgi?user=".&urlize($user).
	  "&enabled=".$target;
return &ui_tag('a', &ui_text_color(&html_escape($label), $type),
	       { 'href' => $url,
		 'class' => 'systemd_linger_toggle',
		 'title' => $title });
}

# systemd_index_boot_column(&unit)
# Returns the formatted startup-state column for a unit row.
sub systemd_index_boot_column
{
my ($u) = @_;
return defined($u->{'boot'}) && $u->{'boot'} == 1 ?
	&ui_text_color("$text{'yes'}", 'success') :
       defined($u->{'boot'}) && $u->{'boot'} == 2 ?
	&ui_text_color("$text{'index_sboot6'}", 'success') :
       defined($u->{'boot'}) && $u->{'boot'} == -1 ?
	&ui_text_color("$text{'index_sboot5'}", 'warn') :
       !defined($u->{'boot'}) ?
	&ui_tag('i', $text{'index_unknown'}) :
	&ui_text_color("$text{'no'}", 'warn');
}

# systemd_index_status_column(&unit)
# Returns the formatted runtime-state column for a unit row.
sub systemd_index_status_column
{
my ($u) = @_;
return defined($u->{'status'}) && $u->{'status'} == 1 ?
	&ui_text_color("$text{'yes'}", 'success') :
       defined($u->{'status'}) && $u->{'status'} == 0 ?
	&ui_text_color("$text{'no'}", 'warn') :
       &ui_tag('i', $text{'index_unknown'});
}
