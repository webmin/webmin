#!/usr/local/bin/perl
# Show a form for selecting a report

require './bandwidth-lib.pl';
&ReadParse();
use Time::Local;
use Socket;

# Validate the bandwidth file
if (-d $bandwidth_log) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro",
			 1, 1);
	&ui_print_endpage(&text('index_elog', "<tt>$bandwidth_log</tt>",
			  "../config.cgi?$module_name"));
	}

# Validate the bandwidth directory
if ($config{'bandwidth_dir'} && !-d $hours_dir) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro",
			 1, 1);
	&ui_print_endpage(&text('index_edir', "<tt>$hours_dir</tt>",
			  "../config.cgi?$module_name"));
	}

# Make sure the net and cron modules work
foreach $m (split(/\s+/, $module_info{'depends'})) {
	next if ($m =~ /^[0-9\.]+$/);
	if (!&foreign_installed($m)) {
		&ui_print_header(undef, $text{'index_title'}, "", "intro",
				 1, 1);
		%minfo = &get_module_info($m);
		&ui_print_endpage(&text('index_emod', $minfo{'desc'}));
		}
	}

# Make sure one of the syslog modules works
if (!$syslog_module) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro",
			 1, 1);
	&ui_print_endpage(&text('index_esyslog'));
	}

# Check the firewall system
if (!$config{'firewall_system'}) {
	# Try automatic detection
	$sys = &detect_firewall_system();
	if (!$sys) {
		&ui_print_header(undef, $text{'index_title'}, "", "intro",
				 1, 1);
		&ui_print_endpage($text{'index_efiresys'});
		}
	$config{'firewall_system'} = $sys;
	&save_module_config();
	}
else {
	# Is the selected one installed?
	if (!&check_firewall_system($config{'firewall_system'})) {
		&ui_print_header(undef, $text{'index_title'}, "", "intro",
				 1, 1);
		&ui_print_endpage(&text('index_efiresys2',
				  $text{'system_'.$config{'firewall_system'}},
				  "../config.cgi?$module_name"));
		}
	}
&ui_print_header(undef, $text{'index_title'}, "", "intro",
		 1, 1, 0, undef, undef, undef,
		 &text('index_firesys',
		       $text{'system_'.$config{'firewall_system'}},
		       $text{'syslog_'.$syslog_module}));

# Make sure the needed firewall rules and syslog entry are in place
$missingrule = !&check_rules();
if ($syslog_module eq "syslog") {
	# Normal syslog
	$conf = &syslog::get_config();
	$sysconf = &find_sysconf($conf);
	}
else {
	# Syslog-ng
	$conf = &syslog_ng::get_config();
	($ngdest, $ngfilter, $nglog) = &find_sysconf_ng($conf);
	$sysconf = $ngdest && $ngfilter && $nglog;
	}

if (($missingrule || !$sysconf) && $access{'setup'}) {
	# Something is missing .. offer to set up
	print "$text{'index_setupdesc'}\n";
	if ($missingrule && !$sysconf) {
		print $text{'index_missing3'};
		}
	elsif ($missingrule) {
		print $text{'index_missing2'};
		}
	elsif (!$sysconf) {
		print $text{'index_missing1'};
		}
	print "<p>\n";
	print "$text{'index_setupdesc2'}<p>\n";
	if ($iptableserr) {
		print $iptableserr,"<p>\n";
		}
	print &ui_form_start("setup.cgi");
	print "<b>$text{'index_iface'}</b>\n";
	foreach $i (&net::active_interfaces(), &net::boot_interfaces()) {
		push(@ifaces, $i->{'fullname'}) if ($i->{'virtual'} eq '' &&
						    $i->{'fullname'});
		}
	print &ui_select("iface", $config{'iface'} || $ifaces[0],
			 [ (map { [ $_, $_ ] } &unique(@ifaces)),
			   [ '', $text{'index_other'} ] ],
			 1, 0, $config{'iface'} ? 1 : 0)." ".
	      &ui_textbox("other", undef, 10);
	print &ui_submit($text{'index_setup'});
	print &ui_form_end();
	print "<p>\n";
	}
elsif ($missingrule || !$sysconf) {
	print "$text{'index_setupdesc'}\n";
	print "$text{'index_setupcannot'}<p>\n";
	}

# See if any hours have been summarized yet
@hours = &list_hours();
if (@hours) {
	# Show reporting form
	print &ui_form_start("index.cgi");
	print "<table>\n";

	print "<tr> <td><b>$text{'index_by'}</b></td>\n";
	print "<td>",&ui_select("by", $in{'by'},
		[ [ 'hour', $text{'index_hour'} ],
		  [ 'day', $text{'index_day'} ],
		  [ 'host', $text{'index_host'} ],
		  [ 'proto', $text{'index_proto'} ],
		  [ 'iport', $text{'index_iport'} ],
		  [ 'oport', $text{'index_oport'} ],
		  [ 'port', $text{'index_port'} ] ]),"</td>\n";

	print "<td><b>$text{'index_for'}</b></td>\n";
	print "<td>",&ui_select("for", $in{'for'},
		[ [ '', $text{'index_all'} ],
		  [ 'host', $text{'index_forhost'} ],
		  [ 'proto', $text{'index_forproto'} ],
		  [ 'iport', $text{'index_foriport'} ],
		  [ 'oport', $text{'index_foroport'} ] ]),"\n";
	print &ui_textbox("what", $in{'for'} ? $in{'what'} : "", 20),
	      "</td> </tr>\n";

	print "<tr> <td><b>$text{'index_from'}</b></td>\n";
	print "<td colspan=4>",
		&date_input($in{'from_day'}, $in{'from_month'},
			    $in{'from_year'}, "from"),
		&hourmin_input($in{'from_hour'}, "00", "from"),"</td> </tr>\n";

	print "<tr> <td><b>$text{'index_to'}</b></td>\n";
	print "<td colspan=4>",
		&date_input($in{'to_day'}, $in{'to_month'},
			    $in{'to_year'}, "to"),
		&hourmin_input($in{'to_hour'}, "00", "to"),"</td> </tr>\n";

	if (!%in) {
		# Enable by default
		$in{'low'} = 1;
		}
	print "<tr> <td></td> <td colspan=4>\n";
	print &ui_checkbox("low", 1, $text{'index_low'}, $in{'low'});
	print &ui_checkbox("resolv", 1, $text{'index_resolv'}, $in{'resolv'});
	print "</td> </tr>\n";

	print "<tr> <td colspan=4>",
		&ui_submit($text{'index_search'}),"</td> </td>\n";

	print "</table>\n";
	print &ui_form_end();
	}
elsif (!$missingrule && $sysconf) {
	print "<b>$text{'index_none'}</b><p>\n";
	}

# Find and show any results
if ($in{'by'}) {
	# Work out the time range, if any
	&error_setup($text{'index_err'});
	$fhour = &parse_hour("from");
	$thour = &parse_hour("to");

	# First find traffic that matches the 'for' part
	if ($in{'for'} eq 'host') {
		if ($in{'what'} =~ /^(\d+)\.(\d+)\.(\d+)\.0$/) {
			%forhost = map { ("$1.$2.$3.$_", 1) } (0 .. 255);
			}
		else {
			$forhost = &to_ipaddress($in{'what'});
			$forhost || &error($text{'index_ehost'});
			$forhost{$forhost}++;
			}
		}
	elsif ($in{'for'} eq 'proto') {
		$forproto = uc($in{'what'});
		$forproto || &error($text{'index_eproto'});
		}
	elsif ($in{'for'} eq 'iport' || $in{'for'} eq 'oport') {
		if ($in{'what'} =~ /^\d+$/) {
			$forportmin = $forportmax = $in{'what'};
			}
		elsif ($in{'what'} =~ /^(\d+)\-(\d+)$/) {
			$forportmin = $1;
			$forportmax = $2;
			}
		else {
			$forportmin = getservbyname($in{'what'}, 'tcp');
			$forportmin ||= getservbyname($in{'what'}, 'udp');
			$forportmin || &error($text{'index_eport'});
			$forportmax = $forportmin;
			}
		}
	foreach $h (@hours) {
		next if ($fhour && $h < $fhour);
		next if ($thour && $h > $thour);
		$hour = &get_hour($h);

		# Work out start time for this day
		@tm = localtime($h*60*60);
		$thisday = timelocal(0, 0, 0, $tm[3], $tm[4], $tm[5])/(60*60);

		# Scan all traffic for the hour
		foreach $k (keys %$hour) {
			# Skip this count if not relevant
			($host, $proto, $iport, $oport) = split(/_/, $k);
			next if (!$proto);
			next if (%forhost && !$forhost{$host});
			next if ($forproto && $proto ne $forproto);
			next if ($in{'for'} eq 'iport' &&
			         ($iport < $forportmin || $iport >$forportmax));
			next if ($in{'for'} eq 'oport' &&
			         ($oport < $forportmin || $oport >$forportmax));

			# Skip this count if classifying by port and there
			# isn't one
			next if ($in{'by'} eq 'iport' && !$iport ||
				 $in{'by'} eq 'oport' && !$oport ||
				 $in{'by'} eq 'port' && !$iport && !$oport);

			# Work out a nice service name
			local ($nsname, $nsoname, $nsiname);
			local $relport;
			if ($in{'by'} eq 'iport') {
				$nsname = $nsiname = getservbyport($iport, lc($proto));
				}
			elsif ($in{'by'} eq 'oport') {
				$nsname = $nsoname = getservbyport($oport, lc($proto));
				}
			elsif ($in{'by'} eq 'port') {
				$nsoname = getservbyport($oport, lc($proto));
				$nsiname = getservbyport($iport, lc($proto));
				$nsname = $nsoname || $nsiname;
				}

			# Resolv the hostname
			local $resolved;
			if ($in{'resolv'} && $in{'by'} eq 'host') {
				$resolved = &to_hostname($host);
				}

			# Skip traffic to high ports, if requested
			next if ($in{'low'} && $in{'by'} eq 'iport' &&
				 $iport >= 1024 && !$nsname);
			next if ($in{'low'} && $in{'by'} eq 'oport' &&
				 $oport >= 1024 && !$nsname);

			# Update the relevant category
			($in, $out) = split(/ /, $hour->{$k});
			if ($in{'by'} eq 'hour') {
				$count{$h} += $in+$out;
				$icount{$h} += $in;
				$ocount{$h} += $out;
				}
			elsif ($in{'by'} eq 'day') {
				$count{$thisday} += $in+$out;
				$icount{$thisday} += $in;
				$ocount{$thisday} += $out;
				}
			elsif ($in{'by'} eq 'host') {
				$count{$resolved || $host} += $in+$out;
				$icount{$resolved || $host} += $in;
				$ocount{$resolved || $host} += $out;
				}
			elsif ($in{'by'} eq 'proto') {
				$count{$proto} += $in+$out;
				$icount{$proto} += $in;
				$ocount{$proto} += $out;
				}
			elsif ($in{'by'} eq 'iport') {
				$count{$nsname || "$proto $iport"} += $in+$out;
				$icount{$nsname || "$proto $iport"} += $in;
				$ocount{$nsname || "$proto $iport"} += $out;
				}
			elsif ($in{'by'} eq 'oport') {
				$count{$nsname || "$proto $oport"} += $in+$out;
				$icount{$nsname || "$proto $oport"} += $in;
				$ocount{$nsname || "$proto $oport"} += $out;
				}
			elsif ($in{'by'} eq 'port') {
				if (!$in{'low'} || $oport < 1024 || $nsoname) {
					$count{$nsoname || "$proto $oport"} += $in;
					$icount{$nsoname || "$proto $oport"} += $in;
					}
				if (!$in{'low'} || $iport < 1024 || $nsiname) {
					$count{$nsiname || "$proto $iport"} += $out;
					$ocount{$nsiname || "$proto $iport"} += $out;
					}
				}
			}
		}

	# Find max and size
	$max = 0;
	foreach $k (keys %count) {
		if ($count{$k} > $max) {
			$max = $count{$k};
			}
		}
	$width = 500;

	# Fill in missing hours or days
	if ($in{'by'} eq 'hour' || $in{'by'} eq 'day') {
		@order = sort { $b <=> $a } keys %count;
		$inc = $in{'by'} eq 'hour' ? 1 : 24;
		$plus = $in{'by'} eq 'hour' ? 0 : 1;
		for($i=$order[0]; $i>=$order[$#order]; $i-=$inc) {
			$count{$i} = 0 if (!$count{$i} &&
					   !$count{$i+$plus} && !$count{$i-$plus});
			}
		}

	# Show graph
	if ($in{'by'} eq 'hour' || $in{'by'} eq 'day') {
		@order = sort { $b <=> $a } keys %count;
		}
	else {
		@order = sort { $count{$b} <=> $count{$a} } keys %count;
		}
	if ($in{'by'} ne 'hour' && $in{'by'} ne 'day') {
		@order = grep { $count{$_} } @order;
		}
	if (@order) {
		print "<table width=100% cellpadding=0 cellspacing=0>\n";
		print "<tr>\n";
		print "<td><b>",$text{'index_h'.$in{'by'}},"</b></td>\n";
		print "<td colspan=2><b>$text{'index_usage'}</b></td>\n";
		print "</tr>\n";
		$total = 0;
		foreach $k (@order) {
			print "<tr>\n";
			if ($in{'by'} eq 'hour') {
				print "<td>",&make_date($k*60*60),"</td>\n";
				}
			elsif ($in{'by'} eq 'day') {
				$date = &make_date_day($k*60*60);
				print "<td>$date</td>\n";
				}
			else {
				print "<td>$k</td>\n";
				}
			print "<td>";
			printf "<img src=images/red.gif width=%d height=10>",
				$max ? int($width * $icount{$k}/$max)+1 : 1;
			printf "<img src=images/blue.gif width=%d height=10>",
				$max ? int($width * $ocount{$k}/$max)+1 : 1;
			print "</td>";
			print "<td>",&nice_size($count{$k}),"</td>\n";
			$total += $count{$k};
			print "</tr>\n";
			}
		print "<tr> <td colspan=2></td> <td><b>",
		&nice_size($total),"</td> </tr>\n";
		print "</table>\n";
		}
	else {
		print "<b>$text{'index_nomatch'}</b><p>\n";
		}
}

if (!$missingrule && $sysconf) {
	print &ui_hr();
	print &ui_buttons_start();

	# Show button to rotate now
	print &ui_buttons_row("rotate.cgi", $text{'index_rotate'},
			      $text{'index_rotatedesc'});

	if ($access{'setup'}) {
		# Show button to turn off reporting
		print &ui_buttons_row("turnoff.cgi", $text{'index_turnoff'},
				      $text{'index_turnoffdesc'});
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

sub parse_hour
{
local ($pfx) = @_;
local ($day, $month, $year) =
	($in{$pfx."_day"}, $in{$pfx."_month"}-1, $in{$pfx."_year"}-1900);
local $hour = $in{$pfx."_hour"};
return undef if (!$day);
if ($hour eq "") {
	$hour = $pfx eq "from" ? 0 : 23;
	}

eval { $tm = timelocal(0, 0, $hour, $day, $month, $year) };
if (!$tm || $@) {
	&error($text{'index_e'.$pfx});
	}
return int($tm/(60*60));
}

# make_date_day(seconds)
# Converts a Unix date/time in seconds to a human-readable form
sub make_date_day
{
local(@tm);
@tm = localtime($_[0]);
return sprintf "%d/%s/%d",
		$tm[3], $text{"smonth_".($tm[4]+1)},
		$tm[5]+1900;
}


