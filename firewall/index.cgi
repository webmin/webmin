#!/usr/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file
# unified for IPV4 and IPV6

require './firewall-lib.pl';
&ReadParse();

# Load the correct library
$ipvx_version = &get_ipvx_version();
if ($ipvx_version == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}

if ($ipvx_save) {
	$desc = &text('index_editing', "<tt>$ipvx_save</tt>");
	}
&ui_print_header($text{"index_title_v${ipvx}"}, $text{'index_title'}, undef,
		 "intro", 1, 1, 0,
		 &help_search_link("ip${ipvx}tables", "man", "doc"));

# Firewall protocol selector
my @vlinks;
push(@vlinks, $ipvx_version == 4 ? "<b>$text{'index_ipvx4'}</b>" :
		&ui_link($ipv4_link, $text{'index_ipvx4'}));
push(@vlinks, $ipvx_version == 6 ? "<b>$text{'index_ipvx6'}</b>" :
		&ui_link($ipv6_link, $text{'index_ipvx6'}));
print "<style>.panel-body b+.ui_link{background-color: lightgrey;} .panel-body b+a+b,",
      ".panel-body b+b{background-color: antiquewhite; padding: .39em 1em .65em 1em; height: 2em; font-size: 1.1em}</style>";
print "<b>$text{'index_ipvxmode'}</b>\n",
      &ui_links_row(\@vlinks),"\n";

print "<br><b>$desc</b><br>&nbsp;";

# Check for iptables and iptables-restore commands
if ($c = &missing_firewall_commands()) {
	print "<p>",&text('index_ecommand', "<tt>$c</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the kernel supports iptables
$out = &backquote_command("ip${ipvx}tables -n -t filter -L OUTPUT 2>&1");
if ($?) {
	print "<p>",&text('index_ekernel', "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the distro supports iptables
if (!$config{"direct${ipvx}"} && defined(&check_iptables) &&
    ($err = &check_iptables())) {
	print "<p>$err</p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if firewall is being started at boot
if (!$config{"direct${ipvx}"} && &foreign_check("init")) {
	$init_support++;
	if (defined(&started_at_boot)) {
		$atboot = &started_at_boot();
		}
	else {
		&foreign_require("init", "init-lib.pl");
		$atboot = &init::action_status("webmin-ip${ipvx}tables") == 2;
		}
	}

# Check if the save file exists. If not, check for any existing firewall
# rules, and offer to create a save file from them
@livetables = &get_iptables_save("ip${ipvx}tables-save 2>/dev/null |");

# Display warnings about active external firewalls!
&external_firewall_message(\@livetables);
if (!$config{"direct${ipvx}"} && $in{'reset'} && $access{'setup'}) {
	@tables = @livetables;
	foreach $t (@tables) {
		$rules++ if (@{$t->{'rules'}});
		foreach $c (keys %{$t->{'defaults'}}) {
			$chains++ if ($t->{'defaults'}->{$c} ne 'ACCEPT');
			}
		$hastable{$t->{'name'}}++;
		}
	foreach $t (@known_tables) {
		system("ip${ipvx}tables -t $t -n -L >/dev/null") if (!$hastable{$t});
		}
	if (!$in{'reset'} && ($rules || $chains)) {
		# Offer to save the current rules
		print &ui_confirmation_form("convert.cgi",
			&text('index_existing', $rules,
			      "<tt>$ipvx_save</tt>"),
			( ['version'], [${ipvx_arg}] ),
			[ [ undef, $text{'index_saveex'} ] ],
			$init_support && !$atboot ?
			  &ui_checkbox("atboot", 1, $text{'index_atboot'}, 0) :
			  "",
			);

		print &ui_table_start($text{'index_headerex'}, "width=100%", 2);
		$out = &backquote_command("ip${ipvx}tables-save 2>/dev/null");
		print &ui_table_row(undef,
			"<pre>".&html_escape($out)."</pre>", 2);
		print &ui_table_end();
		}
	else {
		# Offer to set up a firewall
		print &text($in{'reset'} ? 'index_rsetup' : 'index_setup',
			    "<tt>$ipvx_save</tt>"),"<p>\n";
		print &ui_form_start("setup${ipvx}.cgi");
                print &ui_hidden("version", ${ipvx_arg});
		print &ui_hidden("reset", $in{'reset'});
		print "<center><table><tr><td>\n";
		print &ui_oneradio("auto", 0, $text{'index_auto0'}, 1),"<p>\n";
		foreach $a (1 .. 5) {
			print &ui_oneradio("auto", $a,
					   $text{'index_auto'.$a}, 0)." ";
			print &interface_choice("iface".$a),"<p>\n";
			}
		print "</td></tr></table>\n";
		print &ui_submit($text{'index_auto'}),"<p>\n";
		if ($init_support && !$atboot) {
			print &ui_checkbox("atboot", 1,
					   $text{'index_atboot'}, 0);
			}
		print "</center>\n";
		print &ui_form_end();
		}
	}
else {
	$form = 0;
	@tables = &get_iptables_save();
	if (!$config{"direct${ipvx}"}) {
		# Verify that all known tables exist, and if not add them to the
		# save file
		foreach $t (@tables) {
			$hastable{$t->{'name'}}++;
			}
		foreach $t (@known_tables) {
			if (!$hastable{$t}) {
				local ($missing) = &get_iptables_save(
				    "ip${ipvx}tables-save --table $t 2>/dev/null |");
				if ($missing) {
					delete($missing->{'line'});
					&save_table($missing);
					}
				$need_reload++;
				}
			}
		@tables = &get_iptables_save() if ($need_reload);
		}

	# Check if the current config is valid
	if (!$config{"direct${ipvx}"}) {
		my $err = &validate_iptables_config();
		if ($err) {
			print "<b>",&text('index_evalid',
					  &html_escape($err)),"</b><p>\n";
			}
		}

	# Work out the default table
	if (!defined($in{'table'})) {
		foreach $t (@tables) {
			if (@{$t->{'rules'}} && &can_edit_table($t->{'name'})) {
				$in{'table'} = $t->{'index'};
				last;
				}
			}
		}
	if (!defined($in{'table'})) {
		foreach $t (@tables) {
			if (&can_edit_table($t->{'name'})) {
				$in{'table'} = $t->{'index'};
				last;
				}
			}
		}
	$table = $tables[$in{'table'}];

	# Allow selection of a table
	print "<table width=100%><tr>\n";
	print "<td>\n";
	print "<form action=index.cgi>\n";
	print "<input type=submit value='$text{'index_change'}'>\n";
        print &ui_hidden("version", ${ipvx_arg});
	print "<select name=table onChange='form.submit()'>\n";
	foreach $t (@tables) {
		if (&can_edit_table($t->{'name'})) {
			printf "<option value=%s %s>%s</option>\n",
			    $t->{'index'}, $t eq $table ? "selected" : "",
			    &text('index_table_'.$t->{'name'}) || $t->{'name'};
			}
		}
	print "</select></form>\n";
	print "</td>\n";
	$form++;

	if ($access{'newchain'}) {
		# Show form to create a chain
		print "<td align=right>\n";
		print "<form action=newchain.cgi>\n";
		print &ui_hidden("table", $in{'table'});
                print &ui_hidden("version", ${ipvx_arg});
		print "<input type=submit value='$text{'index_cadd'}'>\n";
		print "<input name=chain size=20></form>\n";
		print "</td>\n";
		$form++;
		}
	print "</tr></table>\n";

        # Display a table of rules for each chain
        CHAIN:
        foreach $c (sort by_string_for_iptables keys %{$table->{'defaults'}}) {
                print &ui_hr();
                @rules = grep { lc($_->{'chain'}) eq lc($c) }
                              @{$table->{'rules'}};
                print "<b>",$text{"index_chain_".lc($c)} ||
                            &text('index_chain', "<tt>$c</tt>"),"</b><br>\n";

                # check if chain is filtered out
                if ($config{'filter_chain'}) {
                    foreach $filter (split(',', $config{'filter_chain'})) {
                        if($c =~ /^$filter$/) {
				# not managed by firewall, do not dispaly or modify
                                print "<em>".$text{'index_filter_chain'}."</em><br>\n";
                                next CHAIN;
                            }
                        }
                    }

                print "<form action=save_policy.cgi>\n";
                print &ui_hidden("version", ${ipvx_arg});
                print &ui_hidden("table", $in{'table'});
                print &ui_hidden("chain", $c);

		if (@rules > $config{'perpage'}) {
		        # Need to show arrows
		        print "<center>\n";
		        $s = int($in{'start'});
		        $e = $in{'start'} + $config{'perpage'} - 1;
		        $e = @rules-1 if ($e >= @rules);
		        if ($s) {
		                print &ui_link("?start=".
		                                ($s - $config{'perpage'}),
		                    "<img src=/images/left.gif border=0 align=middle>");
		                }
		        print "<font size=+1>",&text('index_position', $s+1, $e+1,
		                                     scalar(@rules)),"</font>\n";
		        if ($e < @rules-1) {
		                print &ui_link("?start=".
		                               ($s + $config{'perpage'}),
		                   "<img src=/images/right.gif border=0 align=middle>");
		                }
		        print "</center>\n";
		        }
		else {
		        # Can show them all
		        $s = 0;
		        $e = @rules - 1;
			}
	
		@rules = @rules[$s..$e];

		if (@rules) {
			@links = ( &select_all_link("d", $form),
				   &select_invert_link("d", $form) );
			print &ui_links_row(\@links);

			# Generate the header
			local (@hcols, @tds);
			push(@hcols, "", $text{'index_action'});
			push(@tds, "width=5", "width=30% nowrap");
			if ($config{'view_condition'}) {
				push(@hcols, $text{'index_desc'});
				push(@tds, "nowrap");
				}
			if ($config{'view_comment'}) {
				push(@hcols, $text{'index_comm'});
				push(@tds, "");
				}
			push(@hcols, $text{'index_move'}, $text{'index_add'});
			push(@tds, "width=32", "width=32");
			print &ui_columns_start(\@hcols, 100, 0, \@tds);

			# Generate a row for each rule
			foreach $r (@rules) {
				$edit = &can_jump($r);
				local @cols;
				local $act =
				  $text{"index_jump_".lc($r->{'j'}->[1])} ||
				  &text('index_jump', $r->{'j'}->[1]);

                                # check if chain jump TO is filtered out
                                local $chain_filtered;
                                if ($config{'filter_chain'}) {
                                        foreach $filter (split(',', $config{'filter_chain'})) {
                                                if($r->{'j'}->[1] =~ /^$filter$/) {
                                                     $chain_filtered=&text('index_filter_chain');
                                                     $act=$act."<br><em>$chain_filtered</em>";
                                           }
                                        }
                                    }
				# chain to jump to is filtered, switch of edit
                                if ($edit && !$chain_filtered) {
					push(@cols, &ui_link("edit_rule.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'})."&idx=$r->{'index'}",$act));
					}
				else {
                                        # add col for not visible checkmark
					push(@cols, "", $act);
					}
				if ($config{'view_condition'}) {
					push(@cols, &describe_rule($r));
					}
				if ($config{'view_comment'}) {
					$cmt = $config{'comment_mod'} ||
					       $r->{'comment'} ?
					    $r->{'comment'}->[1] : $r->{'cmt'};
					push(@cols, $cmt);
					}

				# Up/down mover
				local $mover;
				if ($r eq $rules[@rules-1]) {
					$mover .= "<img src=images/gap.gif>";
					}
				else {
					$mover .= "<a href='move.cgi?version=${ipvx_arg}&table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "down=1'><img src=".
					      "images/down.gif border=0></a>";
					}
				if ($r eq $rules[0]) {
					$mover .= "<img src=images/gap.gif>";
					}
				else {
					$mover .= "<a href='move.cgi?version=${ipvx_arg}&table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "up=1'><img src=images/up.gif ".
					      "border=0></a>";
					}
				push(@cols, $mover);

				# Before / after adder
				local $adder;
				$adder .= "<a href='edit_rule.cgi?version=${ipvx_arg}&table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "after=$r->{'index'}'><img src=".
				      "images/after.gif border=0></a>";
				$adder .= "<a href='edit_rule.cgi?version=${ipvx_arg}&table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "before=$r->{'index'}'><img src=".
				      "images/before.gif border=0></a>";
                                push(@cols, $adder);
				# chain to jump to is filtered, switch of edit
				if ($edit && !$chain_filtered) {
                                        print &ui_checked_columns_row(
                                            \@cols, \@tds, "d", $r->{'index'});
                                        }
                                else {
                                        print &ui_columns_row(\@cols, \@tds);
                                        }
                                }
			print &ui_columns_end();
			print &ui_links_row(\@links);
			}
		else {
			print "<b>$text{'index_none'}</b><br>\n";
			}

		# Show policy changing button for chains that support it,
		# and rule-adding button
		print "<table width=100%><tr>\n";
		local $d = $table->{'defaults'}->{$c};
		if ($d ne '-') {
			# Built-in chain
			if ($access{'policy'}) {
				# Change default button
				print "<td width=33% nowrap>",
				      &ui_submit($text{'index_policy'}),"\n";
				print "<select name=policy>\n";
				foreach $t ('ACCEPT','DROP','QUEUE','RETURN') {
					printf "<option value=%s %s>%s</option>\n",
						$t, $d eq $t ? "selected" : "",
						$text{"index_policy_".lc($t)};
					}
				print "</select></td>\n";
				}
			else {
				print "<td width=33%></td>\n";
				}
			print "<td align=center width=33%>\n";
			if (@rules) {
				# Delete selected button
				print &ui_submit($text{'index_cdeletesel'},
						 "delsel"),"\n";

				# Move selected button
				print &ui_submit($text{'index_cmovesel'},
						 "movesel"),"\n";
				}
			print "</td>\n";
			}
		else {
			# Custom chain
			if ($access{'delchain'}) {
				# Delete and rename chain buttons
				print "<td width=33%>",
				   &ui_submit($text{'index_cdelete'}, "delete"),
				   "\n",
				   &ui_submit($text{'index_crename'}, "rename"),
				   "</td>\n";
				}
			print "<td align=center width=33%>\n";
			if (@rules) {
				# Clear chain button
				if ($access{'delchain'}) {
					print &ui_submit($text{'index_cclear'},
							 "clear"),"\n";
					}

				# Delete rules button
				print &ui_submit($text{'index_cdeletesel'},
						 "delsel"),"\n";

				# Move selected button
				print &ui_submit($text{'index_cmovesel'},
						 "movesel"),"\n";
				}
			print "</td>\n";
			}
		print "<td align=right width=33%>",
		      &ui_submit($text{'index_radd'}, "add"),"</td>\n";
		print "</tr></table></form>\n";
		$form++;
		}


	# Show ipset overview if ipsets are availibe
        # may need to check if they are used by firewall rules
	@ipsets  = &get_ipsets_active();
	if (@ipsets) {	
	    print &ui_hr();
	    print "<b>$text{'index_ipset_title'}</b>";
	    # Generate the header
	    local (@hcols, @tds);
	    push(@hcols, $text{'index_ipset'}, "<b>$text{'index_ipset_name'}</b>&nbsp;&nbsp;", $text{'index_ipset_type'},
				 $text{'index_ipset_elem'}, $text{'index_ipset_maxe'}, $text{'index_ipset_size'});
	    push(@tds, "", "", "", "", "");
	    print &ui_columns_start(\@hcols, 100, 0, \@tds);
	    # Generate a row for each rule
	    foreach $s (@ipsets) {
		local @cols;
		local @h= split(/ /, $s->{'Header'});
		# print matching pínet version
		if ($h[1] =~ /inet${ipvx}$/) {
			push(@cols, "&nbsp;&nbsp;$h[0] $h[1]", "&nbsp;&nbsp;<b>$s->{'Name'}</b>",
					$s->{'Type'}, $s->{'Number'}, $h[5], $s->{'Size'});
			print &ui_columns_row(\@cols, \@tds);
			}
                }
	    print &ui_columns_end();
	    }

	# Display buttons for applying and un-applying the configuration,
	# and for creating an init script if possible
	print &ui_hr();
	print &ui_buttons_start();

	if (!$config{"direct${ipvx}"}) {
		# Buttons to apply and reset the config
		if (&foreign_check("servers")) {
			@servers = &list_cluster_servers();
			}
		if ($access{'apply'}) {
			print &ui_buttons_row("apply.cgi",
				$text{'index_apply'},
				@servers ? $text{'index_applydesc2'}
					 : $text{'index_applydesc'},
				[ [ "table", $in{'table'} ] ]);
			}

		if ($access{'unapply'}) {
			print &ui_buttons_row("unapply.cgi",
				$text{'index_unapply'},
				$text{'index_unapplydesc'},
				[ [ "table", $in{'table'} ] ]);
			}

		if ($init_support && $access{'bootup'}) {
			print &ui_buttons_row("bootup.cgi",
				$text{'index_bootup'},
				$text{'index_bootupdesc'},
				[ [ "table", $in{'table'} ] ],
				&ui_yesno_radio("boot", $atboot));
			}

		if ($access{'setup'}) {
			print &ui_buttons_row("index.cgi",
				$text{'index_reset'}, $text{'index_resetdesc'},
				[ [ "reset", 1 ] ]);
			}
		}
	else {
		# Button to save the live config in a file
		if ($access{'unapply'}) {
			print &ui_buttons_row("unapply.cgi",
				$text{'index_unapply2'},
				$text{'index_unapply2desc'},
				[ [ "table", $in{'table'} ] ]);
			}
		}

	# Show button for cluster page
	if (&foreign_check("servers")) {
		&foreign_require("servers", "servers-lib.pl");
		@allservers = grep { $_->{'user'} }
				&servers::list_servers();
		}
	if ($access{'cluster'} && @allservers) {
		print &ui_buttons_row(
			"cluster.cgi", $text{'index_cluster'},
			$text{'index_clusterdesc'});
		}

	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

sub external_firewall_message
   {
	local $fwname="";
	local $fwconfig="$gconfig{'webprefix'}/config.cgi?firewall";

	# detect external firewalls
	local ($filter) = grep { $_->{'name'} eq 'filter' } @{$_[0]};
	if ($filter->{'defaults'}->{'shorewall'}) {
        $fwname.='shorewall ';
        	}
	if ($filter->{'defaults'}->{'INPUT_ZONES'}) {
        	$fwname.='firewalld ';
        	}
	if ($filter->{'defaults'} =~ /^f2b-|^fail2ban-/ && !$config{'filter_chain'} ) {
        	$fwname.='fail2ban ';
        	}
	# warning about not using direct
	if($fwname && !$config{"direct${ipvx}"}) {
                print "<b><center>",
                &text('index_filter_nodirect', $fwconfig),
                "</b></center><p>\n";
           }
        # alert about the detected firewall modules
        foreach my $word (split ' ', $fwname) {
                print ui_alert_box(&text("index_$word", "$gconfig{'webprefix'}/$word/", $fwconfig), 'warn');
                }
   }
