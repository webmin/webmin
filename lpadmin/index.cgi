#!/usr/local/bin/perl
# index.cgi
# Display a list of all known printers

require './lpadmin-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 undef, undef, undef,
		 &text('index_style',
			$text{'style_'.$config{'print_style'}} ||
			uc($config{'print_style'})));
@plist = &list_printers();

# Check the print system (if possible)
if (defined(&check_print_system)) {
	$pserr = &check_print_system();
	if ($pserr) {
		print $pserr,"\n";
		print &text('index_esystem',
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Create links to select / add
@links = ( );
if (@plist && !$config{'display_mode'}) {
	push(@links, &select_all_link("d"),
		     &select_invert_link("d") );
	}
push(@links, "<a href=edit_printer.cgi?new=1>$text{'index_add'}</a>")
	if ($access{'add'});

if ($config{'sort_mode'}) {
	@plist = sort { $a cmp $b } @plist;
	}
if (@plist) {
	if ($config{'display_mode'}) {
		# Just show printer names
		print &ui_links_row(\@links);
		@grid = ( );
		$i = 0;
		foreach $p (@plist) {
			local $ed = &can_edit_printer($p);
			local $jb = &can_edit_jobs($p);
			next if (!$ed && !$jb && !$access{'view'});
			local $l;
			if ($ed) {
				$l = &ui_link("edit_printer.cgi?name=$p", $p)."\n";
				}
			else {
				$l = $p."\n";
				}
			if ($config{'show_jobs'}) {
				local @jobs = &get_jobs($p->{'name'});
				$l .= "&nbsp;<a href='list_jobs.cgi?name=$p'>".
				      "(".&text('index_jcount', scalar(@jobs)).
				      ")</a>";
				}
			else {
				$l .= "&nbsp;<a href='list_jobs.cgi?name=$p'>".
				      "($text{'index_jlist'})</a>";
				}
			push(@grid, $l);
			}
		print &ui_grid_table(\@grid, 4, 100,
			[ "width=25%", "width=25%", "width=25%", "width=25%" ],
			undef,
			$text{'index_header'});
		print &ui_links_row(\@links);
		}
	else {
		# Show full printer details .. table heading first
		if ($access{'delete'}) {
			print &ui_form_start("delete_printers.cgi", "post");
			@tds = ( "width=5" );
			print &ui_links_row(\@links);
			}
		print &ui_columns_start([
			$access{'delete'} ? ( "" ) : ( ),
			$text{'index_name'},
			$text{'index_desc'},
			$text{'index_to'},
			$config{'show_status'} ? ( $text{'index_enabled'},
						   $text{'index_accepting'} )
					       : ( $text{'index_driver'} ),
			$text{'index_jobs'} ], 100, 0, \@tds);

		# One row per printer
		for($i=0; $i<@plist; $i++) {
			local ($wdrv, $hdrv, $drv);
			local $ed = &can_edit_printer($plist[$i]);
			local $jb = &can_edit_jobs($plist[$i]);
			next if (!$ed && !$jb && !$access{'view'});
			$p = &get_printer($plist[$i], !$config{'show_status'});
			$ed = 0 if ($p->{'ro'});

			local @cols;
			if ($ed) {
				push(@cols, "<a href=\"edit_printer.cgi?".
					    "name=$p->{'name'}\">".
					    &html_escape($p->{'name'})."</a>");
				}
			else {
				push(@cols, &html_escape($p->{'name'}));
				}
			push(@cols, &html_escape($p->{'desc'}));
			if (!$webmin_windows_driver) {
				$wdrv = &is_webmin_windows_driver($p->{'iface'}, $p);
				}
			$wdrv = &is_windows_driver($p->{'iface'}, $p) if (!$wdrv);
			$hdrv = &is_hpnp_driver($p->{'iface'}, $p);
			if ($wdrv) {
				push(@cols, "<tt>\\\\$wdrv->{'server'}".
				      	    "\\$wdrv->{'share'}</tt>");
				$p->{'iface'} = $wdrv->{'program'};
				}
			elsif ($hdrv) {
				push(@cols, "<tt>HPNP $hdrv->{'server'}:".
					    "$hdrv->{'port'}</tt>");
				$p->{'iface'} = $hdrv->{'program'};
				}
			elsif ($p->{'rhost'}) {
				local $qu = $p->{'rqueue'} ? $p->{'rqueue'}
							   : $p->{'name'};
				push(@cols, "<tt>$p->{'rhost'}:$qu</tt>");
				}
			elsif ($p->{'dhost'}) {
				push(@cols, "<tt>$p->{'dhost'}:$p->{'dport'}</tt>");
				}
			else {
				push(@cols, &dev_name($p->{'dev'}));
				}
			if (!$webmin_print_driver) {
				$drv = &is_webmin_driver($p->{'iface'}, $p);
				}
			$drv = &is_driver($p->{'iface'}, $p)
				if ($drv->{'mode'} == 0 || $drv->{'mode'} == 2);
			if ($config{'show_status'}) {
				push(@cols, $p->{'enabled'} ? $text{'yes'}
							    : $text{'no'});
				push(@cols, $p->{'accepting'} ? $text{'yes'}
							      : $text{'no'});
				}
			else {
				push(@cols, &html_escape($drv->{'desc'}));
				}
			$jlink = "<a href=\"list_jobs.cgi?name=$p->{'name'}\">";
			if ($config{'show_jobs'}) {
				local @jobs = &get_jobs($p->{'name'});
				$jlink .= scalar(@jobs);
				}
			else {
				$jlink .= $text{'index_list'};
				}
			$jlink .= "</a>";
			push(@cols, $jlink);
			if (!$access{'delete'}) {
				# Cannot delete
				print &ui_columns_row(\@cols, \@tds);
				}
			elsif ($ed) {
				# Can delete
				print &ui_checked_columns_row(\@cols, \@tds,
							      "d",$p->{'name'});
				}
			else {
				# Cannot delete this one
				print &ui_columns_row([ "", @cols ], \@tds);
				}
			}
		print &ui_columns_end();
		if ($access{'delete'}) {
			print &ui_links_row(\@links);
			print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
			}
		}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

# display button to start or stop the scheduler (lpd, lpsched, etc..)
print &ui_hr();
print &ui_buttons_start();
$pid = &sched_running();
if ($pid < 0 || !$access{'stop'}) {
	# cannot stop or start..
	}
elsif ($pid && $access{'stop'} == 2) {
	# can only restart
	print &ui_buttons_row("restart.cgi",
			      $text{'index_restart'}, $text{'index_restartmsg'});
	}
elsif ($pid) {
	print &ui_buttons_row("stop.cgi",
			      $text{'index_stop'}, $text{'index_stopmsg'});
	}
else {
	print &ui_buttons_row("start.cgi",
			      $text{'index_start'}, $text{'index_startmsg'});
	}

# Show cluster button, if possible
if (&foreign_check("servers")) {
	&foreign_require("servers", "servers-lib.pl");
	@allservers = grep { $_->{'user'} }
			&servers::list_servers();
	}
if ($access{'cluster'} && @allservers) {
	print &ui_buttons_row("cluster.cgi",
		      $text{'index_cluster'}, $text{'index_clusterdesc'});
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});


