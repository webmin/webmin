#!/usr/local/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './firewall-lib.pl';
&ReadParse();
if ($iptables_save_file) {
	$desc = &text('index_editing', "<tt>$iptables_save_file</tt>");
	}
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
	&help_search_link("iptables", "man", "doc"), undef, undef, $desc);

# Check for iptables and iptables-restore commands
if ($c = &missing_firewall_commands()) {
	print "<p>",&text('index_ecommand', "<tt>$c</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the kernel supports iptables
$out = &backquote_command("iptables -n -t filter -L OUTPUT 2>&1");
if ($?) {
	print "<p>",&text('index_ekernel', "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the distro supports iptables
if (!$config{'direct'} && defined(&check_iptables) &&
    ($err = &check_iptables())) {
	print "<p>$err</p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if firewall is being started at boot
if (!$config{'direct'} && &foreign_check("init")) {
	$init_support++;
	if (defined(&started_at_boot)) {
		$atboot = &started_at_boot();
		}
	else {
		&foreign_require("init", "init-lib.pl");
		$atboot = &init::action_status("webmin-iptables") == 2;
		}
	}

# Check if the save file exists. If not, check for any existing firewall
# rules, and offer to create a save file from them
@livetables = &get_iptables_save("iptables-save 2>/dev/null |");
&shorewall_message(\@livetables);
&firewalld_message(\@livetables);
&fail2ban_message(\@livetables);
if (!$config{'direct'} &&
    (!-s $iptables_save_file || $in{'reset'}) && $access{'setup'}) {
	@tables = @livetables;
	foreach $t (@tables) {
		$rules++ if (@{$t->{'rules'}});
		foreach $c (keys %{$t->{'defaults'}}) {
			$chains++ if ($t->{'defaults'}->{$c} ne 'ACCEPT');
			}
		$hastable{$t->{'name'}}++;
		}
	foreach $t (@known_tables) {
		system("iptables -t $t -n -L >/dev/null") if (!$hastable{$t});
		}
	if (!$in{'reset'} && ($rules || $chains)) {
		# Offer to save the current rules
		print &ui_confirmation_form("convert.cgi",
			&text('index_existing', $rules,
			      "<tt>$iptables_save_file</tt>"),
			undef,
			[ [ undef, $text{'index_saveex'} ] ],
			$init_support && !$atboot ?
			  &ui_checkbox("atboot", 1, $text{'index_atboot'}, 0) :
			  "",
			);

		print &ui_table_start($text{'index_headerex'}, "width=100%", 2);
		$out = &backquote_command("iptables-save 2>/dev/null");
		print &ui_table_row(undef,
			"<pre>".&html_escape($out)."</pre>", 2);
		print &ui_table_end();
		}
	else {
		# Offer to set up a firewall
		print &text($in{'reset'} ? 'index_rsetup' : 'index_setup',
			    "<tt>$iptables_save_file</tt>"),"<p>\n";
		print &ui_form_start("setup.cgi");
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
	if (!$config{'direct'}) {
		# Verify that all known tables exist, and if not add them to the
		# save file
		foreach $t (@tables) {
			$hastable{$t->{'name'}}++;
			}
		foreach $t (@known_tables) {
			if (!$hastable{$t}) {
				local ($missing) = &get_iptables_save(
				    "iptables-save --table $t 2>/dev/null |");
				if ($missing) {
					delete($missing->{'line'});
					&save_table($missing);
					}
				$need_reload++;
				}
			}
		@tables = &get_iptables_save() if ($need_reload);
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
	print "<form action=index.cgi>\n";
	print "<td><input type=submit value='$text{'index_change'}'>\n";
	print "<select name=table onChange='form.submit()'>\n";
	foreach $t (@tables) {
		if (&can_edit_table($t->{'name'})) {
			printf "<option value=%s %s>%s</option>\n",
			    $t->{'index'}, $t eq $table ? "selected" : "",
			    &text('index_table_'.$t->{'name'}) || $t->{'name'};
			}
		}
	print "</select></td></form>\n";
	$form++;

	if ($access{'newchain'}) {
		# Show form to create a chain
		print "<form action=newchain.cgi>\n";
		print "<td align=right>",&ui_hidden("table", $in{'table'});
		print "<input type=submit value='$text{'index_cadd'}'>\n";
		print "<input name=chain size=20></td></form>\n";
		print "</tr></table>\n";
		$form++;
		}

	# Display a table of rules for each chain
	foreach $c (sort by_string_for_iptables keys %{$table->{'defaults'}}) {
		print &ui_hr();
		@rules = grep { lc($_->{'chain'}) eq lc($c) }
			      @{$table->{'rules'}};
		print "<b>",$text{"index_chain_".lc($c)} ||
			    &text('index_chain', "<tt>$c</tt>"),"</b><br>\n";
		print "<form action=save_policy.cgi>\n";
		print &ui_hidden("table", $in{'table'});
		print &ui_hidden("chain", $c);
		if (@rules) {
			@links = ( &select_all_link("d", $form),
				   &select_invert_link("d", $form) );
			print &ui_links_row(\@links);

			# Generate the header
			local (@hcols, @tds);
			push(@hcols, "", $text{'index_action'});
			push(@tds, "width=5", "width=10% nowrap");
			if ($config{'view_condition'}) {
				push(@hcols, $text{'index_desc'});
				push(@tds, "");
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
				if ($edit) {
					push(@cols, &ui_link("edit_rule.cgi?table=".&urlize($in{'table'})."&idx=$r->{'index'}",$act));
					}
				else {
					push(@cols, $act);
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
					$mover .= "<a href='move.cgi?table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "down=1'><img src=".
					      "images/down.gif border=0></a>";
					}
				if ($r eq $rules[0]) {
					$mover .= "<img src=images/gap.gif>";
					}
				else {
					$mover .= "<a href='move.cgi?table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "up=1'><img src=images/up.gif ".
					      "border=0></a>";
					}
				push(@cols, $mover);

				# Before / after adder
				local $adder;
				$adder .= "<a href='edit_rule.cgi?table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "after=$r->{'index'}'><img src=".
				      "images/after.gif border=0></a>";
				$adder .= "<a href='edit_rule.cgi?table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "before=$r->{'index'}'><img src=".
				      "images/before.gif border=0></a>";
				push(@cols, $adder);

				if ($edit) {
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

	# Display buttons for applying and un-applying the configuration,
	# and for creating an init script if possible
	print &ui_hr();
	print &ui_buttons_start();

	if (!$config{'direct'}) {
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

sub shorewall_message
{
local ($filter) = grep { $_->{'name'} eq 'filter' } @{$_[0]};
if ($filter->{'defaults'}->{'shorewall'}) {
	print "<b><center>",
	      &text('index_shorewall', "$gconfig{'webprefix'}/shorewall/"),
	      "</b></center><p>\n";
	}
}

sub firewalld_message
{
local ($filter) = grep { $_->{'name'} eq 'filter' } @{$_[0]};
if ($filter->{'defaults'}->{'INPUT_ZONES'}) {
	print "<b><center>",
	      &text('index_firewalld', "$gconfig{'webprefix'}/firewalld/"),
	      "</b></center><p>\n";
	}
}

sub fail2ban_message
{
local ($filter) = grep { $_->{'name'} eq 'filter' } @{$_[0]};
if ($filter->{'defaults'} ~~ /^f2b-|^fail2ban-/) {
        print "<b><center>",
              &text('index_fail2ban', "$gconfig{'webprefix'}/fail2ban/"),
              "</b></center><p>\n";
        }
}

